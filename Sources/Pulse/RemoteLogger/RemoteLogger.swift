// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Network
import Combine
import SwiftUI

/// Connects to the remote server and sends logs remotely. In the current version,
/// a server is a Pulse Pro app for macOS).
///
/// - warning: Has to be used from the main thread.
public final class RemoteLogger: ObservableObject, RemoteLoggerConnectionDelegate {
    public private(set) var store: LoggerStore?

    @Published
    public private(set) var browserState: NWBrowser.State = .setup

    @Published
    public private(set) var browserError: NWError?

    @Published
    public private(set) var servers: Set<NWBrowser.Result> = []

    @Published
    public private(set) var connectionState: ConnectionState = .idle {
        didSet { pulseLog(label: "RemoteLogger", "Did change connection state to: \(connectionState.description)")}
    }

    @Published
    public private(set) var connectionError: ConnectionError?

    // Browsing
    private var isStarted = false
    private var browser: NWBrowser?

    // Connections
    private var connection: Connection?
    private var connectedServer: NWBrowser.Result?
    private var serverVersion: Version?
    private var connectionRetryItem: DispatchWorkItem?
    private var timeoutDisconnectItem: DispatchWorkItem?
    private var pingItem: DispatchWorkItem?
    private let keychain = Keychain(service: "com.github.kean.pulse")
    private let connectionQueue = DispatchQueue(label: "com.github.kean.pulse.remote-logger")

    public enum ConnectionState {
        case idle, connecting, connected
    }
    
    public var isOpenOnMacSupported: Bool {
        guard let serverVersion = serverVersion else { return false }
        return serverVersion >= Version(4, 0, 0)
    }

    @AppStorage("com-github-kean-pulse-is-remote-logger-enabled")
    public private(set) var isEnabled = false

    @AppStorage("com-github-kean-pulse-selected-server")
    private var preferredServer = ""

    /// The servers that you previously connected to. The logger will prioritize
    /// connecting to the ``RemoteLogger/selectedServer``, but if it's not found
    /// it'll pick the first server from the ``RemoteLogger/knownServers``.
    @Published
    public private(set) var knownServers: [String] = []

    @AppStorage("com-github-kean-pulse-known-servers")
    private var savedKnownServers = "[]"

    public enum ConnectionError: Error {
        case network(NWError)
    }

    // Logging
    private var isLoggingPaused = true
    private var buffer: [LoggerStore.Event]? = []
    private var cancellable: AnyCancellable?
    private var getMockedResponseCompletions: [UUID: (URLSessionMockedResponse?) -> Void] = [:]

    private var isInitialized = false

    public static let shared = RemoteLogger()

    /// - parameter store: The store to be synced with the server. By default,
    /// ``LoggerStore/shared``. Only one store can be synced at at time.
    public func initialize(store: LoggerStore = .shared) {
        guard self.store !== store else {
            return
        }
        self.store = store
        if isInitialized {
            cancel()
        }
        isInitialized = true

        if isEnabled {
            startBrowser()
        }

        cancellable = store.events.receive(on: connectionQueue).sink { [weak self] in
            self?.didReceive(event: $0)
        }

        // The buffer is used to cover the time between the app launch and the
        // initial (automatic) connection to the server.
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) { [weak self] in
            self?.buffer = nil
        }
    }

    private init() {
        self.knownServers = getKnownServers()

        // Migrate to version 4
        if !preferredServer.isEmpty, knownServers.isEmpty {
            self.knownServers = [preferredServer]
            self.saveKnownServers()
            self.preferredServer = ""
        }
    }

    /// Enables remote logging. The logger will start searching for available
    /// servers.
    public func enable() {
        isEnabled = true
        startBrowser()
    }

    /// Disables remote logging and disconnects from the server.
    public func disable() {
        isEnabled = false
        cancel()
    }

    private func cancel() {
        guard isStarted else { return }
        isStarted = false

        cancelBrowser()
        cancelConnection()
    }

    // MARK: Browsing

    private func startBrowser() {
        guard !isStarted else { return }
        isStarted = true

        pulseLog(label: "RemoteLogger", "Will start browser")

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: RemoteLogger.serviceType, domain: nil), using: parameters)

        browser.stateUpdateHandler = { [weak self] newState in
            guard let self = self, self.isEnabled else { return }

            pulseLog(label: "RemoteLogger", "Browser did update state: \(newState)")
            self.browserState = newState

            switch newState {
            case .waiting(let error):
                browserError = error
            case .failed(let error):
                browserError = error
                self.scheduleBrowserRetry()
            default:
                browserError = nil
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self = self, self.isEnabled else { return }

            pulseLog(label: "RemoteLogger", "Found servers \(results.map { $0.endpoint.debugDescription })")

            self.servers = results
            self.connectAutomaticallyIfNeeded()
        }

        // Start browsing and ask for updates.
        browser.start(queue: .main)

        self.browser = browser
    }

    private func scheduleBrowserRetry() {
        guard isStarted else { return }

        // Automatically retry until the user cancels
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) { [weak self] in
            guard let self = self, self.isStarted else { return }
            self.cancel()
            self.startBrowser()
        }
    }

    private func connectAutomaticallyIfNeeded() {
        guard isStarted, connectedServer == nil else { return }

        var servers: [String: NWBrowser.Result] = [:]
        for server in self.servers where server.name != nil {
            servers[server.name!] = server
        }

        guard let name = self.knownServers.first(where: { servers[$0] != nil }),
              let server = servers[name] else {
            return
        }

        pulseLog(label: "RemoteLogger", "Will connect automatically to \(server.endpoint)")

        connect(to: server, passcode: getPasscode(for: server))
    }

    private func cancelBrowser() {
        browser?.cancel()
        browser = nil
    }

    // MARK: Connection

    public func getPasscode(for server: NWBrowser.Result) -> String? {
        server.name.flatMap(keychain.string)
    }

    public func setPasscode(_ passcode: String?, for server: NWBrowser.Result) {
        guard let name = server.name else { return }
        if let passcode {
            try? keychain.set(passcode, forKey: name)
        } else {
            try? keychain.deleteItem(forKey: name)
        }
    }

    /// Returns `true` if the server is selected.
    public func isSelected(_ server: NWBrowser.Result) -> Bool {
        server == connectedServer
    }

    /// Connects to the given server and saves the selection persistently. Cancels
    /// the existing connection.
    public func connect(to server: NWBrowser.Result, passcode: String? = nil) {
        guard let name = server.name else {
            return pulseLog(label: "RemoteLogger", "Server name is missing")
        }

        // Save selection for the future
        saveServer(named: name)

        switch connectionState {
        case .idle:
            openConnection(to: server, passcode: passcode)
        case .connecting, .connected:
            guard connectedServer != server else { return }
            cancelConnection()
            openConnection(to: server, passcode: passcode)
        }
    }

    private func saveServer(named name: String) {
        knownServers.removeAll(where: { $0 == name })
        knownServers.append(name)
        saveKnownServers()
    }

    private func openConnection(to server: NWBrowser.Result, passcode: String?) {
        connectedServer = server
        connectionState = .connecting

        pulseLog(label: "RemoteLogger", "Will start a connection to server with endpoint \(server.endpoint)")

        let server = servers.first(where: { $0.name == server.name }) ?? server

        #warning("remove passcode on connection error if connection fails on manual connect")
        let connection: Connection
        if server.isProtected, let passcode {
            connection = Connection(endpoint: server.endpoint, using: .init(passcode: passcode))
        } else {
            connection = Connection(endpoint: server.endpoint, using: .tcp)
        }
        connection.delegate = self
        connection.start(on: DispatchQueue.main)
        self.connection = connection
    }

    // MARK: RemoteLoggerConnectionDelegate

    func connection(_ connection: Connection, didChangeState newState: NWConnection.State) {
        guard connectionState != .idle else { return }

        pulseLog(label: "RemoteLogger", "Connection did update state: \(newState)")
        connectionError = nil

        switch newState {
        case .ready:
            handshakeWithServer()
        case .failed(let error):
            connectionError = .network(error)
            scheduleConnectionRetry()
        default:
            break
        }
    }

    func connection(_ connection: Connection, didReceiveEvent event: Connection.Event) {
        guard connectionState != .idle else { return }

        switch event {
        case .packet(let packet):
            do {
                try didReceiveMessage(packet: packet)
            } catch {
                pulseLog(label: "RemoteLogger", "Invalid message from the server: \(error)")
            }
        case .error:
            scheduleConnectionRetry()
        case .completed:
            break
        }
    }

    // MARK: Communication

    private func handshakeWithServer() {
        assert(connection != nil)

        pulseLog(label: "RemoteLogger", "Will send hello to the server")

        // Say "hello" to the server and share information about the client
        let body = PacketClientHello(
            version: Version.currentProtocolVersion.description,
            deviceId: getDeviceId() ?? getFallbackDeviceId(),
            deviceInfo: .make(),
            appInfo: .make(),
            session: store?.session
        )
        connection?.send(code: .clientHello, entity: body)

        // Set timeout and retry in case there was no response from the server
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(10)) { [weak self] in
            guard let self = self else { return } // Failed to connect in 10 sec

            guard self.connectionState == .connecting else { return }
            pulseLog(label: "RemoteLogger", "The handshake with the server timed out")
            self.scheduleConnectionRetry()
        }
    }

    private func didReceiveMessage(packet: Connection.Packet) throws {
        let code = RemoteLogger.PacketCode(rawValue: packet.code)

        pulseLog(label: "RemoteLogger", "Did receive packet with code: \(String(describing: code))")

        switch code {
        case .serverHello:
            guard connectionState != .connected else { return }
            connectionState = .connected
            if let response = try? JSONDecoder().decode(ServerHelloResponse.self, from: packet.body) {
                serverVersion = try Version(string: response.version) // Throw should never happen
            } else {
                serverVersion = nil
            }
            schedulePing()
        case .pause:
            isLoggingPaused = true
        case .resume:
            isLoggingPaused = false
            buffer?.forEach(send)
        case .ping:
            scheduleAutomaticDisconnect()
        case .updateMocks:
            let mocks = try JSONDecoder().decode([URLSessionMock].self, from: packet.body)
            URLSessionMockManager.shared.update(mocks)
        case .getMockedResponse:
            let response = try JSONDecoder().decode(GetMockResponse.self, from: packet.body)
            if let completion = getMockedResponseCompletions.removeValue(forKey: response.requestID) {
                completion(response.mock)
            }
            break
        case .message:
            guard let message = try? Message.decode(packet.body) else {
                return // New unsupported message
            }
            switch message.path {
            case .updateMocks:
                let mocks = try JSONDecoder().decode([URLSessionMock].self, from: message.data)
                URLSessionMockManager.shared.update(mocks)
            case .getMockedResponse, .openMessageDetails, .openTaskDetails:
                break // Server specific (should never happen)
            }
        default:
            break // Do nothing
        }
    }

    private func scheduleConnectionRetry() {
        guard connectionState != .idle, connectionRetryItem == nil else { return }

        cancelPingPong()

        connectionState = .connecting

        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.connectionRetryItem = nil
            guard self.connectionState == .connecting,
                  let server = self.connectedServer else { return }
            self.openConnection(to: server, passcode: getPasscode(for: server))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2), execute: item)
        connectionRetryItem = item
    }

    private func scheduleAutomaticDisconnect() {
        timeoutDisconnectItem?.cancel()

        guard connectionState == .connected else { return }

        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard self.connectionState == .connected else { return }
            pulseLog(label: "RemoteLogger", "Haven't received pings from a server in a while, disconnecting")
            self.scheduleConnectionRetry()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(4), execute: item)
        timeoutDisconnectItem = item
    }

    private func schedulePing() {
        connection?.send(code: .ping)

        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard self.connectionState == .connected else { return }
            self.schedulePing()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2), execute: item)
        pingItem = item
    }

    private func cancelConnection() {
        connectionState = .idle // The order is important
        connectedServer = nil

        connection?.cancel()
        connection = nil

        connectionRetryItem?.cancel()
        connectionRetryItem = nil

        cancelPingPong()
    }

    private func cancelPingPong() {
        timeoutDisconnectItem?.cancel()
        timeoutDisconnectItem = nil

        pingItem?.cancel()
        pingItem = nil
    }

    // MARK: Logging

    private func didReceive(event: LoggerStore.Event) {
        if isLoggingPaused {
            buffer?.append(event)
        } else {
            send(event: event)
        }
    }

    private func send(event: LoggerStore.Event) {
        switch event {
        case .messageStored(let message):
            connection?.send(code: .storeEventMessageStored, entity: message)
        case .networkTaskCreated(let event):
            connection?.send(code: .storeEventNetworkTaskCreated, entity: event)
        case .networkTaskProgressUpdated(let event):
            connection?.send(code: .storeEventNetworkTaskProgressUpdated, entity: event)
        case .networkTaskCompleted(let message):
            do {
                let data = try RemoteLogger.PacketNetworkMessage.encode(message)
                connection?.send(code: .storeEventNetworkTaskCompleted, data: data)
            } catch {
                pulseLog(label: "RemoteLogger", "Failed to encode network message \(error)")
            }
        }
    }

    // MARK: Mocks

    func getMockedResponse(for mock: URLSessionMock, _ completion: @escaping (URLSessionMockedResponse?) -> Void) {
        guard let connection = connection else {
            return completion(nil)
        }
        if let version = serverVersion, version >= Version(4, 0, 0) {
            connection.sendMessage(path: .getMockedResponse(mockID: mock.mockID)) { data, _ in
                if let data = data, let response = try? JSONDecoder().decode(URLSessionMockedResponse.self, from: data) {
                    completion(response)
                } else {
                    completion(nil)
                }
            }
        } else {
            let request = GetMockRequest(requestID: UUID(), mockID: mock.mockID)
            getMockedResponseCompletions[request.requestID] = completion
            connection.send(code: .getMockedResponse, entity: request)
        }
    }
    
    // MARK: Details
    
    public func showDetails(for message: LoggerMessageEntity) {
        connection?.sendMessage(path: .openMessageDetails, entity: LoggerStore.Event.MessageCreated(message))
    }
    
    public func showDetails(for task: NetworkTaskEntity) {
        connection?.sendMessage(path: .openTaskDetails, entity: LoggerStore.Event.NetworkTaskCompleted(task))
    }


    // MARK: Persistence

    private func getKnownServers() -> [String] {
        let data = self.savedKnownServers.data(using: .utf8) ?? Data()
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    private func saveKnownServers() {
        guard let data = try? JSONEncoder().encode(knownServers) else { return }
        self.savedKnownServers = String(data: data, encoding: .utf8) ?? "[]"
    }

}

// MARK: - Helpers

private func getFallbackDeviceId() -> UUID {
    let key = "com-github-com-kean-pulse-device-id"
    if let value = UserDefaults.standard.string(forKey: key), let uuid = UUID(uuidString: value) {
        return uuid
    }
    let id = UUID()
    UserDefaults.standard.set(id.uuidString, forKey: key)
    return id
}

private extension NWBrowser.Result {
    var name: String? {
        switch endpoint {
        case .service(let name, _, _, _):
            return name
        default:
            return nil
        }
    }

    var isProtected: Bool {
        switch metadata {
        case .bonjour(let record):
            return record["protected"].map { Bool($0) } == true
        case .none:
            return false
        @unknown default:
            return false
        }
    }
}

extension RemoteLogger.ConnectionState {
    var description: String {
        switch self {
        case .idle: return "ConnectionState.idle"
        case .connecting: return "ConnectionState.connecting"
        case .connected: return "ConnectionState.connected"
        }
    }
}

extension RemoteLogger {
    public static let serviceType = "_pulse._tcp"
}

func pulseLog(label: String? = nil, _ message: @autoclosure () -> String) {
#if DEBUG && PULSE_DEBUG_LOG_ENABLED
    let prefix = label.map { "[\($0)] " } ?? ""
    NSLog(prefix + message())
#endif
}

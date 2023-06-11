// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Network
import Combine
import SwiftUI
import OSLog

/// Connects to the remote server and sends logs remotely. In the current version,
/// a server is a Pulse Pro app for macOS).
///
/// - warning: Has to be used from the main thread.
public final class RemoteLogger: ObservableObject, RemoteLoggerConnectionDelegate {
    /// The store that the logger was initialized with.
    public private(set) var store: LoggerStore?

    @Published
    public private(set) var browserState: NWBrowser.State = .setup {
        didSet { os_log("Set browser state %{public}@", log: log, "\(oldValue) → \(browserState)") }
    }

    @Published
    public private(set) var browserError: NWError?

    @Published
    public private(set) var servers: Set<NWBrowser.Result> = [] {
        didSet { os_log("Set servers: %{private}@", log: log, "\(servers.map { $0.name ?? "" })") }
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

    @Published
    public private(set) var selectedServerName: String?

    @Published
    public private(set) var connectionState: ConnectionState = .disconnected {
        didSet { os_log("Set public connection state %{public}@", log: log, "\(oldValue) → \(connectionState)") }

    }

    // Browsing
    private var browser: NWBrowser?
    private var selectedServerPasscode: String?
    private var serverVersion: Version?

    // Connections
    private var connectionCompletion: ((Result<Void, ConnectionError>) -> Void)?
    private var connection: Connection?
    private var connectionTimeoutItem: DispatchWorkItem?
    private var connectionError: ConnectionError?
    private var connectionRetryItem: DispatchWorkItem?
    private var timeoutDisconnectItem: DispatchWorkItem?
    private var pingItem: DispatchWorkItem?

    // Logging
    private var isLoggingPaused = true
    private var buffer: [LoggerStore.Event]? = []
    private var cancellable: AnyCancellable?
    private var getMockedResponseCompletions: [UUID: (URLSessionMockedResponse?) -> Void] = [:]

    // Private
    private var isInitialized = false
    private let keychain = Keychain(service: "com.github.kean.pulse")
    private let connectionQueue = DispatchQueue(label: "com.github.kean.pulse.remote-logger")
    private let log: OSLog

    public enum ConnectionState {
        case disconnected, connecting, connected
    }
    
    public var isOpenOnMacSupported: Bool {
        guard let serverVersion = serverVersion else { return false }
        return serverVersion >= Version(4, 0, 0)
    }

    @AppStorage("com-github-kean-pulse-known-servers")
    private var savedKnownServers = "[]"

    public enum ConnectionError: Error, LocalizedError {
        case network(NWError)
        case unknown(isProtected: Bool)

        public var errorDescription: String? {
            switch self {
            case .network(let error):
                return error.localizedDescription
            case .unknown(let isProtected):
                return "Connection failed. Please\(isProtected ? " verify the password and" : "") try again."
            }
        }
    }

    public static let shared = RemoteLogger()

    /// - parameter store: The store to be synced with the server. By default,
    /// ``LoggerStore/shared``. Only one store can be synced at at time.
    public func initialize(store: LoggerStore = .shared) {
        assert(Thread.isMainThread)
        os_log("Initialize with store at %{private}@", log: log, "\(store.storeURL)")

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
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) { [weak self, log] in
            self?.buffer = nil
            os_log("Did clear buffer", log: log)
        }
    }

    private init() {
        let isLogEnabled = UserDefaults.standard.bool(forKey: "com.github.kean.pulse.debug")
        self.log = isLogEnabled ? OSLog(subsystem: "com.github.kean.pulse", category: "RemoteLogger") : .disabled

        self.knownServers = getKnownServers()

        os_log("Did init with known servers: %{private}@", log: log, knownServers.debugDescription)

        // Migrate to version 4
        if !preferredServer.isEmpty, knownServers.isEmpty {
            os_log("Did migrate preferred server: %{private}@", log: log, preferredServer)
            self.knownServers = [preferredServer]
            self.saveKnownServers()
            self.preferredServer = ""
        }
    }

    /// Enables remote logging. The logger will start searching for available
    /// servers.
    public func enable() {
        assert(Thread.isMainThread)
        guard !isEnabled else { return }
        isEnabled = true

        os_log("Will enable", log: log)
        defer { os_log("Did enable", log: log) }

        startBrowser()
    }

    /// Disables remote logging and disconnects from the server.
    public func disable() {
        assert(Thread.isMainThread)
        guard isEnabled else { return }
        isEnabled = false

        os_log("Will disable", log: log)
        defer { os_log("Did disable", log: log) }

        cancel()
    }

    private func getDebugState() -> String {
        "(isEnabled: \(isEnabled))"
    }

    private func cancel() {
        assert(Thread.isMainThread)
        os_log("Will cancel", log: log)
        defer { os_log("Did cancel", log: log) }

        stopBrowser()
        disconnect()
    }

    // MARK: Browsing

    private func startBrowser() {
        os_log("Will start browser", log: log)
        defer { os_log("Did start browser", log: log) }

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: RemoteLogger.serviceType, domain: nil), using: parameters)
        browser.stateUpdateHandler = { [weak self] in
            self?.browserDidUpdateState($0)
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.browserDidUpdateResults(results)
        }
        browser.start(queue: .main)

        self.browser = browser
    }

    private func browserDidUpdateState(_ newState: NWBrowser.State) {
        os_log("Browser did update state to %{public}@", log: log, "\(newState)")

        browserState = newState
        browserError = nil

        switch newState {
        case .waiting(let error):
            os_log("Browser waiting with error: %{public}@", log: log, type: .error, error.debugDescription)
            browserError = error
        case .failed(let error):
            os_log("Browser failed with error: %{public}@", log: log, type: .error, error.debugDescription)
            browserError = error
            scheduleBrowserRetry()
        case .ready:
            servers = browser?.browseResults ?? []
        case .cancelled:
            servers = []
        default:
            break
        }
    }

    private func browserDidUpdateResults(_ results: Set<NWBrowser.Result>) {
        servers = results
        connectAutomaticallyIfNeeded()
        if connectionRetryItem != nil, results.contains(where: { $0.name == selectedServerName }) {
            os_log("Did rediscover server: %{private}@", log: log, selectedServerName ?? "")
            retryConnection()
        }
    }

    private func scheduleBrowserRetry() {
        os_log("Did scheduled browser retry", log: log)

        // Automatically retry until the user cancels
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) { [weak self] in
            guard let self = self, self.isEnabled else { return }
            self.stopBrowser()
            self.startBrowser()
        }
    }

    private func connectAutomaticallyIfNeeded() {
        guard selectedServerName == nil else { return }

        var servers: [String: NWBrowser.Result] = [:]
        for server in self.servers where server.name != nil {
            servers[server.name!] = server
        }

        guard let name = self.knownServers.first(where: { servers[$0] != nil }),
              let server = servers[name] else {
            return
        }

        os_log("Will autoconnect to server: %{private}@", log: log, name)
        connect(to: server, passcode: server.name.flatMap(getPasscode))
    }

    private func stopBrowser() {
        os_log("Will stop browser", log: log)
        defer { os_log("Did stop browser", log: log) }

        browser?.stateUpdateHandler = nil
        browser?.browseResultsChangedHandler = nil
        browser?.cancel()
        browser = nil
        browserError = nil
        browserState = .cancelled
        servers = []
    }

    // MARK: Connection

    /// Returns `true` if the server is selected.
    public func isSelected(_ server: NWBrowser.Result) -> Bool {
        server.name == selectedServerName
    }

    /// Connects to the selected server.
    ///
    /// If the connection is successful, the server is saved to the list of
    /// "known" servers and the passcode is stored in the keychain.
    public func connect(to server: NWBrowser.Result, passcode: String? = nil, _ completion: ((Result<Void, ConnectionError>) -> Void)? = nil) {
        guard let name = server.name else {
            return os_log("Server name is missing", log: log, type: .error)
        }

        guard selectedServerName != name else { return }

        disconnect()

        if let completion {
            os_log("Starting connection timeout", log: log)
            connectionCompletion = completion

            // There seems to be no good way to catch the incorrect TLS
            // encryption key error, so the connection has a 5 second timeout.
            let work = DispatchWorkItem { [weak self] in
                self?.connectionDidTimeout(isProtected: passcode != nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5), execute: work)
            connectionTimeoutItem = work
        }

        openConnection(to: server, passcode: passcode)
    }

    private func connectionDidTimeout(isProtected: Bool) {
        os_log("Connection did timeout", log: log)
        connectionCompletion?(.failure(self.connectionError ?? .unknown(isProtected: isProtected)))
        connectionCompletion = nil
        disconnect()
    }

    /// Forget the server with the given name, disconnecting it, removing the
    /// passcode, and removing it from the list of known servers.
    public func forgetServer(named name: String) {
        os_log("Forget server  %{private}@", log: log, name)
        knownServers.removeAll(where: { $0 == name })
        saveKnownServers()
        setPasscode(nil, forServerNamed: name)
        disconnect()
    }

    private func saveServer(named name: String) {
        os_log("Save server  %{private}@", log: log, name)
        knownServers.removeAll(where: { $0 == name })
        knownServers.append(name)
        saveKnownServers()
    }

    private func openConnection(to server: NWBrowser.Result, passcode: String?) {
        os_log("Will open connection to %{private}@ with endpoint %{private}@", log: log, server.name ?? "–", "\(server.endpoint)")

        selectedServerName = server.name
        selectedServerPasscode = passcode

        let connection: Connection
        if server.isProtected, let passcode {
            os_log("Create .tls connection", log: log)
            connection = Connection(endpoint: server.endpoint, using: .init(passcode: passcode))
        } else {
            os_log("Create .tcp connection", log: log)
            connection = Connection(endpoint: server.endpoint, using: .tcp)
        }
        connection.delegate = self

        self.connectionState = .connecting
        self.connection = connection

        connection.start(on: DispatchQueue.main)
    }

    // MARK: RemoteLoggerConnectionDelegate

    func connection(_ connection: Connection, didChangeState newState: NWConnection.State) {
        os_log("Connection did change state to %{public}@", log: log, "\(newState)")

        switch newState {
        case .ready:
            handshakeWithServer()
        case .waiting(let error):
            os_log("Connection failed with error: %{public}@", log: log, type: .error, error.debugDescription)
            connectionError = nil
        case .failed(let error):
            os_log("Connection failed with error: %{public}@", log: log, type: .error, error.debugDescription)
            connectionError = .network(error)
            connectionState = .disconnected
            scheduleConnectionRetry()
        default:
            break
        }
    }

    func connection(_ connection: Connection, didReceiveEvent event: Connection.Event) {
        switch event {
        case .packet(let packet):
            do {
                try didReceiveMessage(packet: packet)
            } catch {
                os_log("Failed to decode packet: %{public}@", log: log, type: .error, "\(error)")
            }
        case .error(let error):
            os_log("Connection received error while receiving data: %{public}@", log: log, type: .error, "\(error)")
            scheduleConnectionRetry()
        case .completed:
            break
        }
    }

    // MARK:

    /// Returns passcode for the sever with the given name.
    public func getPasscode(forServerNamed name: String) -> String? {
        keychain.string(forKey: name)
    }

    /// Sets or removed passcode for the server with the given name.
    public func setPasscode(_ passcode: String?, forServerNamed name: String) {
        if let passcode {
            try? keychain.set(passcode, forKey: name)
        } else {
            try? keychain.deleteItem(forKey: name)
        }
    }

    // MARK: Communication

    private func handshakeWithServer() {
        assert(connection != nil)

        os_log("Will send hello to the server", log: log)

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
            self?.handshakeDidTimeout()
        }
    }

    private func handshakeDidTimeout() {
        guard connectionState == .connecting else { return }
        os_log("The handshake with the server timed out", log: log)
        scheduleConnectionRetry()
    }

    private func didReceiveMessage(packet: Connection.Packet) throws {
        let code = RemoteLogger.PacketCode(rawValue: packet.code)

        if let code {
            os_log("Did receive packet with code: %{public}@", log: log, type: .info, String(describing: code))
        } else {
            os_log("Did receive packet with unsupported code: %{public}@", log: log, type: .info, String(describing: packet.code))
        }

        switch code {
        case .serverHello:
            let response = try? JSONDecoder().decode(ServerHelloResponse.self, from: packet.body)
            didConnectToServer(response: response)
        case .pause:
            isLoggingPaused = true
        case .resume:
            isLoggingPaused = false
            buffer?.forEach(send)
        case .ping:
            scheduleAutomaticDisconnect()
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

    private func didConnectToServer(response: ServerHelloResponse?) {
        os_log("Did receive hello from server (version: %{public}@)", log: log, response?.version ?? "–")

        guard connectionState != .connected else { return }
        connectionState = .connected

        connectionCompletion?(.success(()))
        connectionCompletion = nil

        os_log("Did cancel connection timeout", log: log)
        connectionTimeoutItem?.cancel()
        connectionTimeoutItem = nil

        if let server = selectedServerName {
            saveServer(named: server)
            if let passcode = selectedServerPasscode {
                setPasscode(passcode, forServerNamed: server)
            }
        }

        if let response {
            serverVersion = try? Version(string: response.version) // Throw should never happen
        } else {
            serverVersion = nil
        }

        schedulePing()
    }

    private func scheduleConnectionRetry() {
        guard connectionRetryItem == nil else { return }

        os_log("Schedule connection retry", log: log)

        cancelPingPong()

        let item = DispatchWorkItem { [weak self] in
            self?.retryConnection()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5), execute: item)
        connectionRetryItem = item
    }

    private func retryConnection() {
        os_log("Retry connection", log: log)

        connectionRetryItem?.cancel()
        connectionRetryItem = nil

        if let server = selectedServerName,
           let server = servers.first(where: { $0.name == server }) {
            openConnection(to: server, passcode: selectedServerName.flatMap(getPasscode))
        } else {
            os_log("Selected serve no longer discoverable", log: log)
            connectionState = .disconnected
            scheduleConnectionRetry()
        }
    }

    private func scheduleAutomaticDisconnect() {
        if timeoutDisconnectItem == nil {
            os_log("Schedule automatic disconnect", log: log)
        }

        timeoutDisconnectItem?.cancel()
        timeoutDisconnectItem = nil

        guard connectionState == .connected else { return }

        let item = DispatchWorkItem { [weak self] in
            self?.didTriggerAutomaticDisconnect()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5), execute: item)
        timeoutDisconnectItem = item
    }

    private func didTriggerAutomaticDisconnect() {
        guard connectionState == .connected else { return }
        os_log("Haven't received pings from a server in a while, disconnecting", log: log)
        connectionState = .disconnected
        scheduleConnectionRetry()
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

    public func disconnect() {
        guard connectionState != .disconnected else { return }
        connectionState = .disconnected // The order is important

        os_log("Disconnect from the current server", log: log)

        selectedServerName = nil
        selectedServerPasscode = nil
        serverVersion = nil

        connection?.cancel()
        connection = nil

        connectionRetryItem?.cancel()
        connectionRetryItem = nil

        connectionTimeoutItem?.cancel()
        connectionTimeoutItem = nil

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
                os_log("Failed to encode network message %{public}@", log: log, type: .error, "\(error)")
            }
        }
    }

    // MARK: Mocks

    func getMockedResponse(for mock: URLSessionMock, _ completion: @escaping (URLSessionMockedResponse?) -> Void) {
        guard let connection = connection else {
            return completion(nil)
        }
        connection.sendMessage(path: .getMockedResponse(mockID: mock.mockID)) { data, _ in
            if let data = data, let response = try? JSONDecoder().decode(URLSessionMockedResponse.self, from: data) {
                completion(response)
            } else {
                completion(nil)
            }
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
        case .disconnected: return "idle"
        case .connecting: return "connecting"
        case .connected: return "connected"
        }
    }
}

extension RemoteLogger {
    public static let serviceType = "_pulse._tcp"
}

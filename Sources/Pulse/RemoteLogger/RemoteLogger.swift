// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import Network
import Combine
import SwiftUI

/// Connects to the remote server and sends logs remotely. In the current version,
/// a server is a Pulse Pro app for macOS).
///
/// The logger is thread-safe. The updates to the `Published` properties will
/// be delivered on a background queue.
@available(iOS 14.0, tvOS 14.0, *)
public final class RemoteLogger: RemoteLoggerConnectionDelegate {
    public private(set) var store: LoggerStore?

    @Published public private(set) var servers: Set<NWBrowser.Result> = []

    // Browsing
    private var isStarted = false
    private var browser: NWBrowser?

    // Connections
    private var connection: Connection?
    private var connectedServer: NWBrowser.Result?
    @Published public private(set) var connectionState: ConnectionState = .idle {
        didSet { log(label: "RemoteLogger", "Did change connection state to: \(connectionState.description)")}
    }
    private var connectionRetryItem: DispatchWorkItem?
    private var timeoutDisconnectItem: DispatchWorkItem?
    private var pingItem: DispatchWorkItem?

    public enum ConnectionState {
        case idle, connecting, connected
    }

    // Logging
    private var isLoggingPaused = true
    private var buffer: [LoggerStore.Event]? = []

    // Persistence
    @AppStorage("com-github-kean-pulse-is-remote-logger-enabled")
    public private(set) var isEnabled = false
    @AppStorage("com-github-kean-pulse-selected-server")
    public private(set) var selectedServer = ""

    private let queue = DispatchQueue(label: "com.github.kean.remote-logger")
    private let specificKey = DispatchSpecificKey<String>()
    private var cancellable: AnyCancellable?

    private var isInitialized = false

    public static let shared = RemoteLogger()

    /// - parameter store: The store to be synced with the server. By default,
    /// ``LoggerStore/shared``. Only one store can be synced at at time.
    public func initialize(store: LoggerStore = .shared) {
        if isInitialized {
            cancel()
        }
        isInitialized = true

        self.store = store

        if isEnabled {
            queue.async(execute: startBrowser)
        }

        cancellable = store.events.receive(on: queue).sink { [weak self] in
            self?.didReceive(event: $0)
        }

        // The buffer is used to cover the time between the app launch and the
        // initial (automatic) connection to the server.
        queue.asyncAfter(deadline: .now() + .seconds(3)) { [weak self] in
            self?.buffer = nil
        }
    }

    /// - parameter store: By default, is initialized with a `default` store.
    private init() {
        queue.setSpecific(key: specificKey, value: "yes")
    }

    /// Enables remote logging. The logger will start searching for available
    /// servers.
    public func enable() {
        isEnabled = true
        queue.async(execute: startBrowser)
    }

    /// Disables remote logging and disconnects from the server.
    public func disable() {
        isEnabled = false
        queue.async(execute: cancel)
    }

    private func cancel() {
        guard isStarted else { return }
        isStarted = false

        cancelBrowser()
        cancelConnection()
    }

    // MARK: Browsing

    private func startBrowser() {
        precondition(DispatchQueue.getSpecific(key: specificKey) != nil)

        guard !isStarted else { return }
        isStarted = true

        log(label: "RemoteLogger", "Will start browser")

        let browser = NWBrowser(for: .bonjour(type: RemoteLogger.serviceType, domain: "local"), using: .tcp)

        browser.stateUpdateHandler = { [weak self] newState in
            guard let self = self, self.isEnabled else { return }

            log(label: "RemoteLogger", "Browser did update state: \(newState)")
            if case .failed = newState {
                self.scheduleBrowserRetry()
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self = self, self.isEnabled else { return }

            log(label: "RemoteLogger", "Found services \(results.map { $0.endpoint.debugDescription })")

            self.servers = results
            self.connectAutomaticallyIfNeeded()
        }

        // Start browsing and ask for updates on the main queue.
        browser.start(queue: queue)

        self.browser = browser
    }

    private func scheduleBrowserRetry() {
        precondition(DispatchQueue.getSpecific(key: specificKey) != nil)

        guard isStarted else { return }

        // Automatically retry until the user cancels
        queue.asyncAfter(deadline: .now() + .seconds(3)) { [weak self] in
            self?.startBrowser()
        }
    }

    private func connectAutomaticallyIfNeeded() {
        precondition(DispatchQueue.getSpecific(key: specificKey) != nil)

        guard isStarted else { return }

        guard !selectedServer.isEmpty, connectedServer == nil,
              let server = self.servers.first(where: { $0.name == selectedServer }) else {
            return
        }

        log(label: "RemoteLogger", "Will connect automatically to \(server.endpoint)")

        connect(to: server)
    }

    private func cancelBrowser() {
        browser?.cancel()
        browser = nil
    }

    // MARK: Connection

    /// Returns `true` if the server is selected.
    public func isSelected(_ server: NWBrowser.Result) -> Bool {
        server.name == selectedServer
    }

    /// Connects to the given server and saves the selection persistently. Cancels
    /// the existing connection.
    public func connect(to server: NWBrowser.Result) {
        guard let name = server.name else {
            return log(label: "RemoteLogger", "Server name is missing")
        }

        // Save selection for the future
        selectedServer = name

        queue.async { self._connect(to: server) }
    }

    private func _connect(to server: NWBrowser.Result) {
        precondition(DispatchQueue.getSpecific(key: specificKey) != nil)

        switch connectionState {
        case .idle:
            openConnection(to: server)
        case .connecting, .connected:
            guard connectedServer != server else { return }
            cancelConnection()
            openConnection(to: server)
        }
    }

    private func openConnection(to server: NWBrowser.Result) {
        precondition(DispatchQueue.getSpecific(key: specificKey) != nil)

        connectedServer = server
        connectionState = .connecting

        log(label: "RemoteLogger", "Will start a connection to server with endpoint \(server.endpoint)")

        let server = servers.first(where: { $0.name == server.name }) ?? server

        let connection = Connection(endpoint: server.endpoint)
        connection.delegate = self
        connection.start(on: queue)
        self.connection = connection
    }

    public func connection(_ connection: Connection, didChangeState newState: NWConnection.State) {
        precondition(DispatchQueue.getSpecific(key: specificKey) != nil)

        guard connectionState != .idle else { return }

        log(label: "RemoteLogger", "Connection did update state: \(newState)")

        switch newState {
        case .ready:
            handshakeWithServer()
        case .failed:
            scheduleConnectionRetry()
        default:
            break
        }
    }

    public func connection(_ connection: Connection, didReceiveEvent event: Connection.Event) {
        precondition(DispatchQueue.getSpecific(key: specificKey) != nil)

        guard connectionState != .idle else { return }

        switch event {
        case .packet(let packet):
            do {
                try didReceiveMessage(packet: packet)
            } catch {
                log(label: "RemoteLogger", "Invalid message from the server: \(error)")
            }
        case .error:
            scheduleConnectionRetry()
        case .completed:
            break
        }
    }

    private func handshakeWithServer() {
        precondition(DispatchQueue.getSpecific(key: specificKey) != nil)

        assert(connection != nil)

        log(label: "RemoteLogger", "Will send hello to the server")

        // Say "hello" to the server and share information about the client
        let deviceId = getDeviceId() ?? getFallbackDeviceId()
        let body = PacketClientHello(deviceId: deviceId, deviceInfo: .make(), appInfo: .make())
        connection?.send(code: .clientHello, entity: body)

        // Set timeout and retry in case there was no response from the server
        queue.asyncAfter(deadline: .now() + .seconds(10)) { [weak self] in
            guard let self = self else { return } // Failed to connect in 10 sec

            guard self.connectionState == .connecting else { return }
            log(label: "RemoteLogger", "The handshake with the server timed out")
            self.scheduleConnectionRetry()
        }
    }

    private func didReceiveMessage(packet: Connection.Packet) throws {
        let code = RemoteLogger.PacketCode(rawValue: packet.code)

        log(label: "RemoteLogger", "Did receive packet with code: \(code?.description ?? "invalid")")

        switch code {
        case .serverHello:
            guard connectionState != .connected else { return }
            connectionState = .connected
            schedulePing()
        case .pause:
            isLoggingPaused = true
        case .resume:
            isLoggingPaused = false
            buffer?.forEach(send)
        case .ping:
            scheduleAutomaticDisconnect()
        default:
            assertionFailure("A packet with an invalid code received from the server: \(packet.code.description)")
        }
    }

    private func scheduleConnectionRetry() {
        precondition(DispatchQueue.getSpecific(key: specificKey) != nil)

        guard connectionState != .idle, connectionRetryItem == nil else { return }

        cancelPingPong()

        connectionState = .connecting

        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.connectionRetryItem = nil
            guard self.connectionState == .connecting,
                  let server = self.connectedServer else { return }
            self.openConnection(to: server)
        }
        queue.asyncAfter(deadline: .now() + .seconds(2), execute: item)
        connectionRetryItem = item
    }

    private func scheduleAutomaticDisconnect() {
        precondition(DispatchQueue.getSpecific(key: specificKey) != nil)

        timeoutDisconnectItem?.cancel()

        guard connectionState == .connected else { return }

        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard self.connectionState == .connected else { return }
            log(label: "RemoteLogger", "Haven't received pings from a server in a while, disconnecting")
            self.scheduleConnectionRetry()
        }
        queue.asyncAfter(deadline: .now() + .seconds(4), execute: item)
        timeoutDisconnectItem = item
    }

    private func schedulePing() {
        connection?.send(code: .ping)

        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard self.connectionState == .connected else { return }
            self.schedulePing()
        }
        queue.asyncAfter(deadline: .now() + .seconds(2), execute: item)
        pingItem = item
    }

    private func cancelConnection() {
        precondition(DispatchQueue.getSpecific(key: specificKey) != nil)

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
        precondition(DispatchQueue.getSpecific(key: specificKey) != nil)

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
                log(label: "RemoteLogger", "Failed to encode network message \(error)")
            }
        }
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
}

@available(iOS 14.0, tvOS 14.0, *)
extension RemoteLogger.ConnectionState {
    public var description: String {
        switch self {
        case .idle: return "ConnectionState.idle"
        case .connecting: return "ConnectionState.connecting"
        case .connected: return "ConnectionState.connected"
        }
    }
}

@available(iOS 14.0, tvOS 14.0, *)
extension RemoteLogger {
    public static let serviceType = "_pulse._tcp"
}

func log(label: String? = nil, _ message: @autoclosure () -> String) {
    #if DEBUG && PULSE_DEBUG_LOG_ENABLED
    let prefix = label.map { "[\($0)] " } ?? ""
    NSLog(prefix + message())
    #endif
}

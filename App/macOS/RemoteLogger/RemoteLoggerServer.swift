// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Cocoa
import Pulse
import SwiftUI
import Combine
import Network

final class RemoteLoggerServer: RemoteLoggerConnectionDelegate, ObservableObject {
    // Listening
    @Published private(set) var isStarted = false
    @Published private(set) var listenerState: NWListener.State = .cancelled
    @Published private(set) var listenerSetupError: Error?

    private var listener: NWListener?
        
    // Clients
    private var connections: [ConnectionId: RemoteLogger.Connection] = [:]
    @Published private(set) var clients: [RemoteLoggerClientId: RemoteLoggerClient] = [:]
    
    // Persistence
    @AppStorage("isRemoteLoggerEnabled")
    private(set) public var isEnabled = true
    
    public static let shared = RemoteLoggerServer()
        
    var onAddClient: ((RemoteLoggerClient) -> Void)?
    
    private let cancellables: [AnyCancellable] = []
    
    deinit {
        pulseLog("RemoteLoggerServer deinit")
    }
        
    init() {
        loadRemoteClients()
    }
    
    func enable() {
        isEnabled = true
        startListenser()
    }
    
    func disable() {
        isEnabled = false
        cancel()
    }
    
    func restart() {
        disable()
        enable()
    }
    
    private func cancel() {
        isStarted = false
        listenerState = .cancelled
        listener?.cancel()
        listener = nil
        listenerSetupError = nil
    }

    private func startListenser() {
        guard !isStarted else { return }
        isStarted = true

        pulseLog("Will start publishing a service")
        
        let listener: NWListener
        do {
            var port: NWEndpoint.Port = .any
            if let customPort = UInt16(AppSettings.shared.port), customPort > 0 {
                port = NWEndpoint.Port(rawValue: customPort) ?? .any
            }
            listener = try NWListener(using: .tcp, on: port)
        } catch {
            pulseLog("Failed to initialize a listener: \(error)")
            self.listenerSetupError = error
            scheduleListenerRetry() // This should never happen
            return
        }
                        
        listenerSetupError = nil

        let customName = AppSettings.shared.serviceName.trimmingCharacters(in: .whitespaces)
        let serviceName = customName.isEmpty ? Host.current().localizedName : customName
        listener.service = NWListener.Service(name: serviceName, type: RemoteLogger.serviceType)
        listener.stateUpdateHandler = { [weak self] state in
            self?.didUpdateState(state)
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.didReceiveNewConnection(connection)
        }
        listener.start(queue: .main)
        
        pulseLog("Did start publishing a service: \(listener) on \(String(describing: listener.port))")

        self.listener = listener
    }
    
    private func didUpdateState(_ newState: NWListener.State) {
        pulseLog("Listener did enter state \(newState.description)")
        self.listenerState = newState
        if case .failed = newState {
            self.scheduleListenerRetry()
        }
    }
    
    private func scheduleListenerRetry() {
        guard isStarted else { return }

        // Automatically retry until the user cancels
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) { [weak self] in
            self?.startListenser()
        }
    }
    
    private func didReceiveNewConnection(_ connection: NWConnection) {
        pulseLog("Did receive connection: \(connection)")
        
        let connection = RemoteLogger.Connection(connection)
        connection.delegate = self
        connection.start(on: .main)
        let id = ConnectionId(connection)
        connections[id] = connection
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(15)) { [weak self] in
            self?.connections[id] = nil
        }
    }
    
    func connection(_ connection: RemoteLogger.Connection, didChangeState newState: NWConnection.State) {
        pulseLog("Connection did update state: \(newState)")

        switch newState {
        case .ready:
            break
        case .failed, .cancelled:
            connections[ConnectionId(connection)] = nil
        default:
            break
        }
    }
    
    func connection(_ connection: RemoteLogger.Connection, didReceiveEvent event: RemoteLogger.Connection.Event) {
        switch event {
        case .packet(let packet):
            do {
                try self.connection(connection, didReceivePacket: packet)
            }  catch {
                pulseLog("Invalid message from the server: \(error)")
            }
        case .error:
            break
        case .completed:
            break
        }
    }
    
    private func connection(_ connection: RemoteLogger.Connection, didReceivePacket packet: RemoteLogger.Connection.Packet) throws {
        let code = RemoteLogger.PacketCode(rawValue: packet.code)
        let client = clients.values.first { $0.connection === connection }
        
        pulseLog("Did receive packet with code: \(code?.description ?? "invalid")")
        
        switch code {
        case .clientHello:
            let request = try JSONDecoder().decode(RemoteLogger.PacketClientHello.self, from: packet.body)
            pulseLog("Device wans to connect: \(request.deviceInfo.name)")
            self.clientDidConnect(connection: connection, request: request)
        case .ping:
            client?.didReceivePing()
        case .storeEventMessageStored:
            let event = try JSONDecoder().decode(LoggerStore.Event.MessageCreated.self, from: packet.body)
            client?.process(event: .messageStored(event))
        case .storeEventNetworkTaskCreated:
            let event = try JSONDecoder().decode(LoggerStore.Event.NetworkTaskCreated.self, from: packet.body)
            client?.process(event: .networkTaskCreated(event))
        case .storeEventNetworkTaskProgressUpdated:
            let event = try JSONDecoder().decode(LoggerStore.Event.NetworkTaskProgressUpdated.self, from: packet.body)
            client?.process(event: .networkTaskProgressUpdated(event))
        case .storeEventNetworkTaskCompleted:
            let message = try RemoteLogger.PacketNetworkMessage.decode(packet.body)
            client?.process(event: .networkTaskCompleted(message))
        default:
            assertionFailure("A packet with an invalid code received from the server: \(packet.code.description)")
        }
    }
    
    private func clientDidConnect(connection: RemoteLogger.Connection, request: RemoteLogger.PacketClientHello) {
        let clientId = RemoteLoggerClientId(request: request)
        if let client = clients[clientId] {
            client.connection = connection
            client.didConnectExistingClient()
        } else {
            do {
                let client = try RemoteLoggerClient(info: .init(info: request))
                client.connection = connection
                clients[clientId] = client
                saveRemoveClients()
                onAddClient?(client)
            } catch {
                pulseLog("Failed to initialize a client \(error)")
            }
        }
        connection.send(code: .serverHello)
    }
    
    // MARK: Managing Clients
    
    private func loadRemoteClients() {
        do {
            let data = try Data(contentsOf: remoteClientsIndexURL)
            let descriptions = try JSONDecoder().decode([RemoteLoggerClientInfo].self, from: data)
            let clients = descriptions.compactMap { try? RemoteLoggerClient(info: $0) }
            for client in clients {
                self.clients[client.id] = client
            }
        } catch {
            // Should never happen
        }
    }
    
    private func saveRemoveClients() {
        do {
            let descriptions = clients.values.map { $0.info }
            let data = try JSONEncoder().encode(descriptions)
            try data.write(to: remoteClientsIndexURL)
        } catch {
            // Should never happen
        }
    }
    
    private var remoteClientsIndexURL: URL {
        URL.library.appending(filename: "RemoteClients").appendingPathExtension("json")
    }
    
    public func remove(client: RemoteLoggerClient) {
        try? Files.removeItem(at: client.store.storeURL)
        clients[client.id] = nil
        saveRemoveClients()
    }
}

struct ConnectionId: Hashable {
    let id: ObjectIdentifier
    
    init(_ connection: RemoteLogger.Connection) {
        self.id = ObjectIdentifier(connection)
    }
}

private extension NWListener.State {
    var description: String {
        switch self {
        case .setup: return ".setup"
        case .waiting(let error): return ".waiting(error: \(error))"
        case .ready: return ".ready"
        case .failed(let error): return ".failed(error: \(error))"
        case .cancelled: return ".cancelled"
        @unknown default: return ".unknown"
        }
    }
}

func pulseLog(_ message: @autoclosure () -> String) {
#if DEBUG && PULSE_DEBUG_LOG_ENABLED
    NSLog(message())
#endif
}

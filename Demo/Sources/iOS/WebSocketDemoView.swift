// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import PulseUI
import PulseProxy
import PulseStarscream
import Starscream

// MARK: - Main Demo View

struct WebSocketDemoView: View {
    @State private var urlSessionStatus = "Not connected"
    @State private var starscreamStatus = "Not connected"
    @State private var apolloStatus = "Not connected"
    @State private var showConsole = false
    
    var body: some View {
        List {
            Section("URLSession WebSocket") {
                Text(urlSessionStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Test URLSession WebSocket") {
                    testURLSessionWebSocket()
                }
            }
            
            Section("Starscream WebSocket") {
                Text(starscreamStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Test Starscream WebSocket") {
                    testStarscreamWebSocket()
                }
            }
            
            Section("Apollo WebSocket (Simulated)") {
                Text(apolloStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Test Apollo WebSocket Logging") {
                    testApolloWebSocket()
                }
                Text("Note: Uses simulated events since Apollo requires a real GraphQL server")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Section("Actions") {
                Button("View Pulse Console") {
                    showConsole = true
                }
            }
        }
        .navigationTitle("WebSocket Demo")
        .sheet(isPresented: $showConsole) {
            NavigationView {
                ConsoleView(store: .shared)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showConsole = false }
                        }
                    }
            }
        }
    }
    
    // MARK: - Apollo WebSocket Demo (Simulated)
    
    private func testApolloWebSocket() {
        apolloStatus = "Simulating Apollo WebSocket..."
        ApolloDemoManager.shared.simulateSubscription { status in
            apolloStatus = status
        }
    }
    
    // MARK: - URLSession WebSocket Demo
    
    private func testURLSessionWebSocket() {
        urlSessionStatus = "Connecting..."
        
        Task {
            do {
                // Use the public WebSocket echo server
                guard let url = URL(string: "wss://echo.websocket.org") else {
                    await MainActor.run { urlSessionStatus = "Invalid URL" }
                    return
                }
                
                // Create session with proxy for logging
                let session = URLSessionProxy(configuration: .default)
                let wsTask = session.webSocketTaskProxy(with: url)
                wsTask.resume()
                
                await MainActor.run { urlSessionStatus = "Connected, sending message..." }
                
                // Send a text message
                try await wsTask.send(.string("Hello from URLSession WebSocket!"))
                
                await MainActor.run { urlSessionStatus = "Message sent, waiting for echo..." }
                
                // Receive the echo
                let message = try await wsTask.receive()
                switch message {
                case .string(let text):
                    await MainActor.run { urlSessionStatus = "Received: \(text.prefix(50))..." }
                case .data(let data):
                    await MainActor.run { urlSessionStatus = "Received \(data.count) bytes" }
                @unknown default:
                    await MainActor.run { urlSessionStatus = "Received unknown message type" }
                }
                
                // Send another message
                try await wsTask.send(.string("{\"type\":\"test\",\"payload\":{\"id\":123,\"name\":\"Demo\"}}"))
                let _ = try await wsTask.receive()
                
                // Close the connection
                wsTask.cancel(with: .normalClosure, reason: nil)
                
                await MainActor.run { urlSessionStatus = "✅ Complete! Check Pulse console." }
                
            } catch {
                await MainActor.run { urlSessionStatus = "Error: \(error.localizedDescription)" }
            }
        }
    }
    
    // MARK: - Starscream WebSocket Demo
    
    private func testStarscreamWebSocket() {
        starscreamStatus = "Connecting..."
        StarscreamDemoManager.shared.connect { status in
            starscreamStatus = status
        }
    }
}

// MARK: - Starscream Demo Manager

/// Manages Starscream WebSocket connection for demo purposes
final class StarscreamDemoManager: WebSocketDelegate {
    static let shared = StarscreamDemoManager()
    
    private var socket: WebSocket?
    private var logger: StarscreamLogger?
    private var statusCallback: ((String) -> Void)?
    private var messageCount = 0
    
    private init() {}
    
    func connect(statusCallback: @escaping (String) -> Void) {
        self.statusCallback = statusCallback
        self.messageCount = 0
        
        guard let url = URL(string: "wss://echo.websocket.org") else {
            statusCallback("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        socket = WebSocket(request: request)
        
        // Enable Pulse logging - this is the key integration!
        logger = socket?.enablePulseLogging(delegate: self)
        
        socket?.connect()
    }
    
    // MARK: - WebSocketDelegate
    
    func didReceive(event: WebSocketEvent, client: any WebSocketClient) {
        switch event {
        case .connected:
            statusCallback?("Connected! Sending messages...")
            
            // Send test messages
            socket?.write(string: "Hello from Starscream!")
            logger?.logSentText("Hello from Starscream!")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                let jsonMessage = "{\"type\":\"starscream_test\",\"data\":{\"id\":456,\"items\":[1,2,3]}}"
                self?.socket?.write(string: jsonMessage)
                self?.logger?.logSentText(jsonMessage)
            }
            
        case .text(let text):
            messageCount += 1
            statusCallback?("Received \(messageCount) message(s): \(text.prefix(30))...")
            
            if messageCount >= 2 {
                // Disconnect after receiving both echoes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.socket?.disconnect()
                    self?.statusCallback?("✅ Complete! Check Pulse console.")
                }
            }
            
        case .binary(let data):
            statusCallback?("Received binary: \(data.count) bytes")
            
        case .disconnected(let reason, let code):
            statusCallback?("Disconnected: \(reason) (code: \(code))")
            
        case .error(let error):
            statusCallback?("Error: \(error?.localizedDescription ?? "unknown")")
            
        case .cancelled:
            statusCallback?("Cancelled")
            
        case .ping, .pong, .viabilityChanged, .reconnectSuggested, .peerClosed:
            break
        }
    }
}

// MARK: - Apollo Demo Manager

/// Simulates Apollo WebSocket events for demo purposes
/// In a real app, these events would come from actual GraphQL subscriptions
final class ApolloDemoManager {
    static let shared = ApolloDemoManager()
    
    private let taskId = UUID()
    private let logger = NetworkLogger.shared
    
    private init() {}
    
    func simulateSubscription(statusCallback: @escaping (String) -> Void) {
        // Create a mock URL for the simulated connection
        guard let url = URL(string: "wss://api.example.com/graphql") else {
            statusCallback("Invalid URL")
            return
        }
        
        statusCallback("Simulating connection...")
        
        // Simulate task creation
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        logger.logEvent(.networkTaskCreated(.init(
            taskId: taskId,
            taskType: .webSocketTask,
            createdAt: Date(),
            originalRequest: NetworkLogger.Request(request),
            currentRequest: nil,
            label: "Apollo Demo",
            taskDescription: "Simulated Apollo WebSocket"
        )))
        
        // Simulate connection opened
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            
            self.logger.logEvent(.webSocketTaskOpened(.init(
                taskId: self.taskId,
                createdAt: Date(),
                protocol: "graphql-transport-ws"
            )))
            
            // Log subscription start
            let subscribeMessage = "{\"type\":\"subscribe\",\"payload\":{\"operationName\":\"UserNotifications\"}}"
            self.logFrame(subscribeMessage, isSent: true)
            statusCallback("Subscription started...")
        }
        
        // Simulate receiving data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            let mockPayload = """
            {"type":"next","operation":"UserNotifications","data":{"notification":{"id":"123","title":"New Message","body":"You have a new notification","createdAt":"2024-12-24T15:00:00Z","read":false}}}
            """
            self?.logFrame(mockPayload, isSent: false)
            statusCallback("Received notification...")
        }
        
        // Simulate another data event
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { [weak self] in
            let mockPayload2 = """
            {"type":"next","operation":"UserNotifications","data":{"notification":{"id":"124","title":"Order Update","body":"Your order has shipped!","createdAt":"2024-12-24T15:01:00Z","read":false,"metadata":{"orderId":"ORD-9876","carrier":"FedEx"}}}}
            """
            self?.logFrame(mockPayload2, isSent: false)
            statusCallback("Received order update...")
        }
        
        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self else { return }
            
            self.logFrame("{\"type\":\"complete\",\"operation\":\"UserNotifications\"}", isSent: false)
            
            self.logger.logEvent(.webSocketTaskClosed(.init(
                taskId: self.taskId,
                createdAt: Date(),
                closeCode: 1000,
                reason: Data("Normal closure".utf8)
            )))
            
            statusCallback("✅ Complete! Check Pulse console.")
        }
    }
    
    private func logFrame(_ message: String, isSent: Bool) {
        let frame = LoggerStore.Event.WebSocketFrame(
            taskId: taskId,
            createdAt: Date(),
            frameType: .text,
            data: Data(message.utf8),
            isTruncated: false
        )
        
        if isSent {
            logger.logEvent(.webSocketFrameSent(frame))
        } else {
            logger.logEvent(.webSocketFrameReceived(frame))
        }
    }
}

// MARK: - Global test function (called from app startup)

func testWebSocket() {
    // This is called on app startup - run a quick URLSession WebSocket test
    Task {
        do {
            guard let url = URL(string: "wss://echo.websocket.org") else { return }
            
            let session = URLSessionProxy(configuration: .default)
            let wsTask = session.webSocketTaskProxy(with: url)
            wsTask.resume()
            
            // Wait a moment for connection
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Send and receive
            try await wsTask.send(.string("Auto-test from Pulse Demo"))
            let _ = try await wsTask.receive()
            
            wsTask.cancel(with: .normalClosure, reason: nil)
            
            NSLog("WebSocket auto-test completed successfully")
        } catch {
            NSLog("WebSocket auto-test error: \(error)")
        }
    }
}

// MARK: - Preview

#if DEBUG
struct WebSocketDemoView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WebSocketDemoView()
        }
    }
}
#endif

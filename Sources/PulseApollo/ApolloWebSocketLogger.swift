// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import ApolloWebSocket
import Apollo
import ApolloAPI

/// A delegate proxy that intercepts Apollo WebSocket events and logs them to Pulse.
///
/// Usage:
/// ```swift
/// let transport = WebSocketTransport(websocket: webSocket, store: apolloStore)
/// let logger = ApolloWebSocketLogger(transport: transport, delegate: self, url: wsURL)
/// transport.delegate = logger
/// ```
///
/// The logger will forward all delegate calls to your original delegate while logging
/// WebSocket connection events and GraphQL subscription messages to Pulse.
public final class ApolloWebSocketLogger: WebSocketTransportDelegate, @unchecked Sendable {
    private let logger: NetworkLogger
    nonisolated(unsafe) private weak var delegate: WebSocketTransportDelegate?
    private let taskId: UUID
    private let url: URL
    private let createdAt: Date
    nonisolated(unsafe) private var hasLoggedTaskCreation = false
    
    /// The underlying Apollo WebSocketTransport being logged.
    nonisolated(unsafe) public private(set) weak var transport: WebSocketTransport?
    
    /// Creates a new ApolloWebSocketLogger.
    /// - Parameters:
    ///   - transport: The Apollo WebSocketTransport to log.
    ///   - delegate: Your original delegate that will receive forwarded events.
    ///   - url: The WebSocket URL (for display in Pulse).
    ///   - logger: The NetworkLogger to use. Defaults to `.shared`.
    public init(
        transport: WebSocketTransport,
        delegate: WebSocketTransportDelegate? = nil,
        url: URL,
        logger: NetworkLogger = .shared
    ) {
        self.transport = transport
        self.delegate = delegate
        self.url = url
        self.logger = logger
        self.taskId = UUID()
        self.createdAt = Date()
    }
    
    // MARK: - WebSocketTransportDelegate
    
    public func webSocketTransportDidConnect(_ webSocketTransport: WebSocketTransport) {
        logTaskCreated()
        logTaskOpened()
        delegate?.webSocketTransportDidConnect(webSocketTransport)
    }
    
    public func webSocketTransportDidReconnect(_ webSocketTransport: WebSocketTransport) {
        // Log as a new connection after reconnect
        logFrame(.text, data: Data("{\"type\":\"reconnected\"}".utf8), isSent: false)
        delegate?.webSocketTransportDidReconnect(webSocketTransport)
    }
    
    public func webSocketTransport(_ webSocketTransport: WebSocketTransport, didDisconnectWithError error: (any Error)?) {
        if let error = error {
            logTaskClosed(reason: error.localizedDescription, code: 1006)
        } else {
            logTaskClosed(reason: "Disconnected", code: 1000)
        }
        delegate?.webSocketTransport(webSocketTransport, didDisconnectWithError: error)
    }
    
    // MARK: - Manual Logging for GraphQL Messages
    
    /// Log a GraphQL subscription message that was sent.
    /// Call this when sending a subscription or other WebSocket message.
    ///
    /// - Parameter message: The GraphQL message payload (typically JSON).
    public func logSentMessage(_ message: String) {
        logTaskCreatedIfNeeded()
        logFrame(.text, data: Data(message.utf8), isSent: true)
    }
    
    /// Log a GraphQL subscription message that was sent.
    /// - Parameter data: The raw message data.
    public func logSentData(_ data: Data) {
        logTaskCreatedIfNeeded()
        logFrame(.binary, data: data, isSent: true)
    }
    
    /// Log a GraphQL subscription message that was received.
    /// - Parameter message: The GraphQL message payload (typically JSON).
    public func logReceivedMessage(_ message: String) {
        logTaskCreatedIfNeeded()
        logFrame(.text, data: Data(message.utf8), isSent: false)
    }
    
    /// Log a GraphQL subscription message that was received.
    /// - Parameter data: The raw message data.
    public func logReceivedData(_ data: Data) {
        logTaskCreatedIfNeeded()
        logFrame(.binary, data: data, isSent: false)
    }
    
    /// Log a GraphQL subscription result as a received message.
    /// - Parameter result: Any Encodable result from a GraphQL subscription.
    public func logReceivedResult<T: Encodable>(_ result: T) {
        logTaskCreatedIfNeeded()
        if let data = try? JSONEncoder().encode(result) {
            logFrame(.text, data: data, isSent: false)
        }
    }
    
    /// Log a GraphQL subscription being started.
    /// - Parameter operationName: The name of the GraphQL subscription operation.
    public func logSubscriptionStarted(_ operationName: String) {
        logTaskCreatedIfNeeded()
        let message = """
        {"type":"subscribe","payload":{"operationName":"\(operationName)"}}
        """
        logFrame(.text, data: Data(message.utf8), isSent: true)
    }
    
    // MARK: - Apollo SelectionSet Logging
    
    /// Log a GraphQL subscription result (success) with the actual payload data.
    /// This method handles Apollo's SelectionSet types and converts them to readable JSON.
    ///
    /// - Parameters:
    ///   - operationName: The name of the GraphQL operation.
    ///   - data: The Apollo SelectionSet data from the subscription result.
    public func logSubscriptionData<T: SelectionSet>(_ operationName: String, data: T) {
        logTaskCreatedIfNeeded()
        
        // Convert Apollo's internal data to JSON-safe format
        let jsonSafeData = Self.convertToJSONSafe(data.__data._data)
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonSafeData, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let message = "{\"type\":\"next\",\"operation\":\"\(operationName)\",\"data\":\(jsonString)}"
            logFrame(.text, data: Data(message.utf8), isSent: false)
        } else {
            // Fallback to string description
            let description = String(describing: data).prefix(2000)
            let escapedDescription = description.replacingOccurrences(of: "\"", with: "\\\"")
            let message = "{\"type\":\"next\",\"operation\":\"\(operationName)\",\"data\":\"\(escapedDescription)\"}"
            logFrame(.text, data: Data(message.utf8), isSent: false)
        }
    }
    
    /// Log a GraphQL subscription error.
    ///
    /// - Parameters:
    ///   - operationName: The name of the GraphQL operation.
    ///   - error: The error that occurred.
    public func logSubscriptionError(_ operationName: String, error: Error) {
        logTaskCreatedIfNeeded()
        let escapedError = error.localizedDescription.replacingOccurrences(of: "\"", with: "\\\"")
        let message = "{\"type\":\"error\",\"operation\":\"\(operationName)\",\"error\":\"\(escapedError)\"}"
        logFrame(.text, data: Data(message.utf8), isSent: false)
    }
    
    // MARK: - JSON Conversion Helpers
    
    /// Recursively converts Apollo's data dictionary to JSON-serializable types.
    /// Handles Apollo's DataDict and other internal types by extracting their underlying data.
    private static func convertToJSONSafe(_ value: Any) -> Any {
        // Handle Apollo's DataDict by extracting its internal data
        if let dataDict = value as? DataDict {
            return convertToJSONSafe(dataDict._data)
        }
        
        // Handle dictionaries
        if let dict = value as? [String: Any] {
            return dict.mapValues { convertToJSONSafe($0) }
        }
        
        // Handle arrays
        if let array = value as? [Any] {
            return array.map { convertToJSONSafe($0) }
        }
        
        // Handle primitive types
        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number
        }
        if let bool = value as? Bool {
            return bool
        }
        if value is NSNull {
            return NSNull()
        }
        
        // Handle Optional by unwrapping
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            if let child = mirror.children.first {
                return convertToJSONSafe(child.value)
            } else {
                return NSNull()
            }
        }
        
        // Handle SelectionSet types by extracting their __data
        if let selectionSet = value as? (any SelectionSet) {
            return convertToJSONSafe(selectionSet.__data._data)
        }
        
        // Last resort: convert to string representation
        return String(describing: value)
    }
    
    // MARK: - Logging Helpers
    
    private func logTaskCreatedIfNeeded() {
        if !hasLoggedTaskCreation {
            logTaskCreated()
            logTaskOpened()
        }
    }
    
    private func logTaskCreated() {
        guard !hasLoggedTaskCreation else { return }
        hasLoggedTaskCreation = true
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        logger.logEvent(.networkTaskCreated(.init(
            taskId: taskId,
            taskType: .webSocketTask,
            createdAt: createdAt,
            originalRequest: NetworkLogger.Request(request),
            currentRequest: nil,
            label: "Apollo GraphQL",
            taskDescription: "Apollo WebSocket Subscription"
        )))
    }
    
    private func logTaskOpened() {
        logger.logEvent(.webSocketTaskOpened(.init(
            taskId: taskId,
            createdAt: Date(),
            protocol: "graphql-transport-ws"
        )))
    }
    
    private func logFrame(_ type: LoggerStore.Event.WebSocketFrame.FrameType, data: Data, isSent: Bool) {
        let frame = LoggerStore.Event.WebSocketFrame(
            taskId: taskId,
            createdAt: Date(),
            frameType: type,
            data: data,
            isTruncated: false
        )
        
        if isSent {
            logger.logEvent(.webSocketFrameSent(frame))
        } else {
            logger.logEvent(.webSocketFrameReceived(frame))
        }
    }
    
    private func logTaskClosed(reason: String, code: UInt16) {
        logger.logEvent(.webSocketTaskClosed(.init(
            taskId: taskId,
            createdAt: Date(),
            closeCode: Int(code),
            reason: Data(reason.utf8)
        )))
    }
}

// MARK: - WebSocketTransport Extension for Easy Integration

public extension WebSocketTransport {
    /// Creates an ApolloWebSocketLogger and sets it as the delegate.
    /// - Parameters:
    ///   - delegate: Your original delegate that will receive forwarded events.
    ///   - url: The WebSocket URL (for display in Pulse).
    ///   - logger: The NetworkLogger to use. Defaults to `.shared`.
    /// - Returns: The ApolloWebSocketLogger instance (retain this to keep logging active).
    @discardableResult
    func enablePulseLogging(
        delegate: WebSocketTransportDelegate? = nil,
        url: URL,
        logger: NetworkLogger = .shared
    ) -> ApolloWebSocketLogger {
        let apolloLogger = ApolloWebSocketLogger(
            transport: self,
            delegate: delegate,
            url: url,
            logger: logger
        )
        self.delegate = apolloLogger
        return apolloLogger
    }
}


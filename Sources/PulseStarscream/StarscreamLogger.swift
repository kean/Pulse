// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import Starscream

/// A delegate proxy that intercepts Starscream WebSocket events and logs them to Pulse.
///
/// Usage:
/// ```swift
/// let socket = WebSocket(request: request)
/// let logger = StarscreamLogger(socket: socket, delegate: self)
/// socket.delegate = logger
/// socket.connect()
/// ```
///
/// The logger will forward all delegate calls to your original delegate while logging
/// WebSocket frames to Pulse.
public final class StarscreamLogger: WebSocketDelegate {
    private let logger: NetworkLogger
    private weak var delegate: WebSocketDelegate?
    private let taskId: UUID
    private let originalRequest: URLRequest
    private let createdAt: Date
    private var hasLoggedTaskCreation = false
    
    /// The underlying Starscream WebSocket being logged.
    public private(set) weak var socket: WebSocket?
    
    /// Creates a new StarscreamLogger.
    /// - Parameters:
    ///   - socket: The Starscream WebSocket to log.
    ///   - delegate: Your original delegate that will receive forwarded events.
    ///   - logger: The NetworkLogger to use. Defaults to `.shared`.
    public init(socket: WebSocket, delegate: WebSocketDelegate? = nil, logger: NetworkLogger = .shared) {
        self.socket = socket
        self.delegate = delegate
        self.logger = logger
        self.taskId = UUID()
        self.originalRequest = socket.request
        self.createdAt = Date()
    }
    
    // MARK: - WebSocketDelegate
    
    public func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
        switch event {
        case .connected(let headers):
            logTaskCreated()
            logTaskOpened(headers: headers)
            
        case .disconnected(let reason, let code):
            logTaskClosed(reason: reason, code: code)
            
        case .text(let string):
            logFrame(.text, data: Data(string.utf8), isSent: false)
            
        case .binary(let data):
            logFrame(.binary, data: data, isSent: false)
            
        case .ping(let data):
            logFrame(.ping, data: data ?? Data(), isSent: false)
            
        case .pong(let data):
            logFrame(.pong, data: data ?? Data(), isSent: false)
            
        case .viabilityChanged, .reconnectSuggested:
            break // Not logged
            
        case .cancelled:
            logTaskClosed(reason: "Cancelled", code: 1000)
            
        case .error(let error):
            logError(error)
            
        case .peerClosed:
            logTaskClosed(reason: "Peer closed", code: 1000)
        }
        
        // Forward to original delegate
        delegate?.didReceive(event: event, client: client)
    }
    
    // MARK: - Logging Helpers
    
    private func logTaskCreated() {
        guard !hasLoggedTaskCreation else { return }
        hasLoggedTaskCreation = true
        
        logger.logEvent(.networkTaskCreated(.init(
            taskId: taskId,
            taskType: .webSocketTask,
            createdAt: createdAt,
            originalRequest: NetworkLogger.Request(originalRequest),
            currentRequest: nil,
            label: "Starscream",
            taskDescription: "Starscream WebSocket"
        )))
    }
    
    private func logTaskOpened(headers: [String: String]) {
        // Extract the WebSocket protocol from headers if available
        let wsProtocol = headers["Sec-WebSocket-Protocol"]
        
        logger.logEvent(.webSocketTaskOpened(.init(
            taskId: taskId,
            createdAt: Date(),
            protocol: wsProtocol
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
    
    private func logError(_ error: Error?) {
        // Log as a close event with error information
        let reason = error?.localizedDescription ?? "Unknown error"
        logTaskClosed(reason: reason, code: 1006) // 1006 = Abnormal Closure
    }
    
    // MARK: - Manual Logging for Sent Messages
    
    /// Call this method after sending a text message to log it.
    /// - Parameter text: The text message that was sent.
    public func logSentText(_ text: String) {
        logFrame(.text, data: Data(text.utf8), isSent: true)
    }
    
    /// Call this method after sending binary data to log it.
    /// - Parameter data: The binary data that was sent.
    public func logSentData(_ data: Data) {
        logFrame(.binary, data: data, isSent: true)
    }
    
    /// Call this method after sending a ping to log it.
    /// - Parameter data: The ping data that was sent.
    public func logSentPing(_ data: Data = Data()) {
        logFrame(.ping, data: data, isSent: true)
    }
}

// MARK: - WebSocket Extension for Easy Integration

public extension WebSocket {
    /// Creates a StarscreamLogger and sets it as the delegate.
    /// - Parameters:
    ///   - delegate: Your original delegate that will receive forwarded events.
    ///   - logger: The NetworkLogger to use. Defaults to `.shared`.
    /// - Returns: The StarscreamLogger instance (retain this to keep logging active).
    @discardableResult
    func enablePulseLogging(delegate: WebSocketDelegate? = nil, logger: NetworkLogger = .shared) -> StarscreamLogger {
        let starscreamLogger = StarscreamLogger(socket: self, delegate: delegate, logger: logger)
        self.delegate = starscreamLogger
        return starscreamLogger
    }
}

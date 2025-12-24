// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

/// A wrapper around `URLSessionWebSocketTask` that intercepts WebSocket frames
/// for logging purposes.
///
/// Since `URLSessionWebSocketTask` uses async methods for sending and receiving
/// messages (rather than delegate callbacks), this wrapper intercepts those calls
/// to log the frames.
///
/// ## Usage
///
/// Instead of using `URLSessionWebSocketTask` directly, use `WebSocketTaskProxy`:
///
/// ```swift
/// let proxy = URLSessionProxy(configuration: .default)
/// let wsProxy = proxy.webSocketTaskProxy(with: url)
/// wsProxy.resume()
///
/// try await wsProxy.send(.string("Hello"))
/// let message = try await wsProxy.receive()
/// ```
public final class WebSocketTaskProxy: @unchecked Sendable {
    /// The underlying `URLSessionWebSocketTask`.
    public let task: URLSessionWebSocketTask

    private let logger: NetworkLogger

    /// Creates a new WebSocket task proxy.
    ///
    /// - Parameters:
    ///   - task: The underlying WebSocket task to wrap.
    ///   - logger: The logger to use for logging frames. Defaults to the shared logger.
    public init(task: URLSessionWebSocketTask, logger: NetworkLogger? = nil) {
        self.task = task
        self.logger = logger ?? .shared
    }

    // MARK: - Sending Messages

    /// Sends a WebSocket message, logging it before transmission.
    ///
    /// - Parameter message: The message to send.
    /// - Throws: An error if sending fails.
    public func send(_ message: URLSessionWebSocketTask.Message) async throws {
        logger.logWebSocketFrameSent(task, message: message)
        try await task.send(message)
    }

    /// Sends a WebSocket message using a completion handler.
    ///
    /// - Parameters:
    ///   - message: The message to send.
    ///   - completionHandler: Called when the send completes.
    public func send(_ message: URLSessionWebSocketTask.Message, completionHandler: @escaping @Sendable (Error?) -> Void) {
        logger.logWebSocketFrameSent(task, message: message)
        task.send(message, completionHandler: completionHandler)
    }

    // MARK: - Receiving Messages

    /// Receives a WebSocket message, logging it after reception.
    ///
    /// - Returns: The received message.
    /// - Throws: An error if receiving fails.
    public func receive() async throws -> URLSessionWebSocketTask.Message {
        let message = try await task.receive()
        logger.logWebSocketFrameReceived(task, message: message)
        return message
    }

    /// Receives a WebSocket message using a completion handler.
    ///
    /// - Parameter completionHandler: Called with the received message or error.
    public func receive(completionHandler: @escaping @Sendable (Result<URLSessionWebSocketTask.Message, Error>) -> Void) {
        task.receive { [logger, task] result in
            if case .success(let message) = result {
                logger.logWebSocketFrameReceived(task, message: message)
            }
            completionHandler(result)
        }
    }

    // MARK: - Ping/Pong

    /// Sends a ping and waits for a pong.
    ///
    /// - Parameter pongReceiveHandler: Called when pong is received or an error occurs.
    public func sendPing(pongReceiveHandler: @escaping @Sendable (Error?) -> Void) {
        logger.logWebSocketPingSent(task)
        task.sendPing { [logger, task] error in
            if error == nil {
                logger.logWebSocketPongReceived(task)
            }
            pongReceiveHandler(error)
        }
    }

    // MARK: - Task Control

    /// Resumes the task.
    public func resume() {
        task.resume()
    }

    /// Suspends the task.
    public func suspend() {
        task.suspend()
    }

    /// Cancels the task.
    public func cancel() {
        task.cancel()
    }

    /// Cancels the task with a close code and optional reason.
    ///
    /// - Parameters:
    ///   - closeCode: The WebSocket close code.
    ///   - reason: Optional data explaining the reason for closing.
    public func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        task.cancel(with: closeCode, reason: reason)
    }

    // MARK: - Task Properties

    /// The close code received from the server, if any.
    public var closeCode: URLSessionWebSocketTask.CloseCode {
        task.closeCode
    }

    /// The close reason received from the server, if any.
    public var closeReason: Data? {
        task.closeReason
    }

    /// The current state of the task.
    public var state: URLSessionTask.State {
        task.state
    }

    /// The task identifier.
    public var taskIdentifier: Int {
        task.taskIdentifier
    }

    /// The original request used to create the task.
    public var originalRequest: URLRequest? {
        task.originalRequest
    }

    /// The current request (may differ from original after redirects).
    public var currentRequest: URLRequest? {
        task.currentRequest
    }

    /// The response received from the server.
    public var response: URLResponse? {
        task.response
    }

    /// The maximum message size that can be received.
    public var maximumMessageSize: Int {
        get { task.maximumMessageSize }
        set { task.maximumMessageSize = newValue }
    }
}


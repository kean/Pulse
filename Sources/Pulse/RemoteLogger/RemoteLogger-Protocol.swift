// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation
import Network

extension RemoteLogger {
    package enum PacketCode: UInt8, Equatable {
        // Handshake
        case clientHello = 0 // PacketClientHello
        case serverHello = 1 // ServerHelloResponse
        // Controls
        case pause = 2
        case resume = 3
        // Ping
        case ping = 6
        // Store events
        case storeEventMessageStored = 7
        case storeEventNetworkTaskCreated = 8
        case storeEventNetworkTaskProgressUpdated = 9
        case storeEventNetworkTaskCompleted = 10
        // A custom message with the following format:
        //
        // path (String)
        // body (Data)
        //
        // Moving forward, all non-control packets will be send using this format.
        case message = 13
    }

    package struct PacketClientHello: Codable {
        package let version: String?
        package let deviceId: UUID
        package let deviceInfo: LoggerStore.Info.DeviceInfo
        package let appInfo: LoggerStore.Info.AppInfo
        package let session: LoggerStore.Session? // Added: 3.5.7
    }

    package struct Empty: Codable {
    }

    package struct PacketNetworkMessage {
        private struct Manifest: Codable {
            let messageSize: UInt32
            let requestBodySize: UInt32
            let responseBodySize: UInt32

            static let size = 12

            var totalSize: Int {
                Manifest.size + Int(messageSize) + Int(requestBodySize) + Int(responseBodySize)
            }
        }

        package static func encode(_ event: LoggerStore.Event.NetworkTaskCompleted) throws -> Data {
            var contents = [Data]()

            var slimEvent = event
            slimEvent.requestBody = nil // Sent separately using binary
            slimEvent.responseBody = nil

            let messageData = try JSONEncoder().encode(slimEvent)
            contents.append(messageData)
            if let requestBody = event.requestBody, requestBody.count < Int32.max {
                contents.append(requestBody)
            }
            if let responseBody = event.responseBody, responseBody.count < Int32.max {
                contents.append(responseBody)
            }

            var data = Data()
            data.append(Data(UInt32(messageData.count)))
            data.append(Data(UInt32(event.requestBody?.count ?? 0)))
            data.append(Data(UInt32(event.responseBody?.count ?? 0)))
            for item in contents {
                data.append(item)
            }
            return data
        }

        package static func decode(_ data: Data) throws -> LoggerStore.Event.NetworkTaskCompleted {
            guard data.count >= Manifest.size else {
                throw PacketParsingError.notEnoughData // Should never happen
            }

            let manifest = Manifest(
                messageSize: UInt32(data.from(0, size: 4)),
                requestBodySize: UInt32(data.from(4, size: 4)),
                responseBodySize: UInt32(data.from(8, size: 4))
            )

            guard data.count >= manifest.totalSize else {
                throw PacketParsingError.notEnoughData // This should never happen
            }

            let event = try JSONDecoder().decode(
                LoggerStore.Event.NetworkTaskCompleted.self,
                from: data.from(Manifest.size, size: Int(manifest.messageSize))
            )

            var requestBody: Data?
            if manifest.requestBodySize > 0 {
                requestBody = data.from(Manifest.size + Int(manifest.messageSize), size: Int(manifest.requestBodySize))
            }

            var responseBody: Data?
            if manifest.responseBodySize > 0 {
                responseBody = data.from(Manifest.size + Int(manifest.messageSize) + Int(manifest.requestBodySize), size: Int(manifest.responseBodySize))
            }

            return LoggerStore.Event.NetworkTaskCompleted(taskId: event.taskId, taskType: event.taskType, createdAt: event.createdAt, originalRequest: event.originalRequest, currentRequest: event.currentRequest, response: event.response, error: event.error, requestBody: requestBody, responseBody: responseBody, metrics: event.metrics, label: event.label, taskDescription: event.taskDescription)
        }
    }

    package struct Message {
        package struct Header {
            package let id: UInt32
            package let options: Options
            package let pathSize: UInt32
            package let dataSize: UInt32

            package init?(_ data: Data) {
                guard data.count >= headerSize else { return nil }
                self.id = UInt32(data.from(0, size: 4))
                self.options = Options(rawValue: data[4])
                self.pathSize = UInt32(data.from(5, size: 4))
                self.dataSize = UInt32(data.from(9, size: 4))
            }
        }

        package struct Options: OptionSet {
            package let rawValue: UInt8
            package init(rawValue: UInt8) { self.rawValue = rawValue }

            package static let response = Options(rawValue: 1 << 0)
        }

        package let id: UInt32
        package let options: Options
        package let path: Path
        package let data: Data

        // - id (UInt32)
        // - options (UInt8)
        // - path size (UInt32)
        // - data size (UInt32)
        private static let headerSize = 13

        package static func encode(_ message: Message) throws -> Data {
            guard let path = try? JSONEncoder().encode(message.path) else {
                throw URLError(.unknown, userInfo: [:]) // Should never happen
            }
            var data = Data()
            // Header
            data.append(Data(message.id))
            data.append(message.options.rawValue)
            data.append(Data(UInt32(path.count)))
            data.append(Data(UInt32(message.data.count)))
            // URL
            data.append(path)
            // Payload
            data.append(message.data)
            return data
        }

        package static func decode(_ data: Data) throws -> Message {
            guard let header = Header(data) else {
                throw PacketParsingError.notEnoughData // Should never happen
            }
            guard data.count >= (headerSize + Int(header.pathSize) + Int(header.dataSize)) else {
                throw PacketParsingError.notEnoughData // This should never happen
            }
            let path = try JSONDecoder().decode(RemoteLogger.Path.self, from: data.from(headerSize, size: Int(header.pathSize)))
            let body = data.from(headerSize + Int(header.pathSize), size: Int(header.dataSize))
            return Message(id: header.id, options: header.options, path: path, data: body)
        }
    }

    package enum PacketParsingError: Error {
        case notEnoughData
        case unsupportedContentSize
    }

    package enum Path: Codable {
        case updateMocks
        case getMockedResponse(mockID: UUID)
        /// Payload: ``LoggerStore/Event/MessageCreated``.
        case openMessageDetails
        /// Payload: ``LoggerStore/Event/NetworkTaskCompleted``.
        case openTaskDetails
    }

    package struct ServerHelloResponse: Codable {
        package let version: String

        package init(version: String) {
            self.version = version
        }
    }
}

extension RemoteLogger.Connection {
    package func send(code: RemoteLogger.PacketCode, data: Data) {
        send(code: code.rawValue, data: data)
    }

    package func send<T: Encodable>(code: RemoteLogger.PacketCode, entity: T) {
        send(code: code.rawValue, entity: entity)
    }

    package func send(code: RemoteLogger.PacketCode) {
        send(code: code.rawValue, entity: RemoteLogger.Empty())
    }
}

package struct URLSessionMock: Hashable, Codable {
    package let mockID: UUID
    package var pattern: String
    package var method: String?
    package var skip: Int?
    package var count: Int?

    package init(mockID: UUID, pattern: String, method: String? = nil, skip: Int? = nil, count: Int? = nil) {
        self.mockID = mockID
        self.pattern = pattern
        self.method = method
        self.skip = skip
        self.count = count
    }

    package func isMatch(_ request: URLRequest) -> Bool {
        if let lhs = request.httpMethod, let rhs = method,
           lhs.uppercased() != rhs.uppercased() {
            return false
        }
        guard let url = request.url?.absoluteString else {
            return false
        }
        return isMatch(url)
    }

    package func isMatch(_ url: String) -> Bool {
        guard let regex = try? Regex(pattern, [.caseInsensitive]) else {
            return false
        }
        return regex.isMatch(url)
    }
}

package struct URLSessionMockedResponse: Codable {
    package let errorCode: Int?
    package let statusCode: Int?
    package let headers: [String: String]?
    package var body: String?

    package init(errorCode: Int?, statusCode: Int?, headers: [String : String]?, body: String? = nil) {
        self.errorCode = errorCode
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

// MARK: - Helpers (Binary Protocol)

// Expects big endian.
extension Data {
    init(_ value: UInt32) {
        var contentSize = value.bigEndian
        self.init(bytes: &contentSize, count: MemoryLayout<UInt32>.size)
    }

    func from(_ from: Data.Index, size: Int) -> Data {
        self[(from + startIndex)..<(from + size + startIndex)]
    }
}

extension UInt32 {
    init(_ data: Data) {
        self = UInt32(data.parseInt(size: 4))
    }
}

private extension Data {
    func parseInt(size: Int) -> UInt64 {
        precondition(size > 0 && size <= 8)
        var accumulator: UInt64 = 0
        for i in 0..<size {
            let shift = (size - i - 1) * 8
            accumulator |= UInt64(self[self.startIndex + i]) << UInt64(shift)
        }
        return accumulator
    }
}

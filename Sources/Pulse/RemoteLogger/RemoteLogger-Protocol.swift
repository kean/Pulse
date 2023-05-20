// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Network
#if PULSE_STANDALONE_APP
import Pulse
#endif

extension RemoteLogger {
    enum PacketCode: UInt8, Equatable {
        // Handshake
        case clientHello = 0 // PacketClientHello
        case serverHello = 1
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
        // Mocks
        case updateMocks = 11 // [URLSessionMock]
        case getMockedResponse = 12 // GetMockRequest / GetMockResponse
        // A custom message with the following format:
        //
        // path (String)
        // body (Data)
        //
        // Moving forward, all non-control packets will be send using this format.
        case message = 13
    }

    struct PacketClientHello: Codable {
        let version: String?
        let deviceId: UUID
        let deviceInfo: LoggerStore.Info.DeviceInfo
        let appInfo: LoggerStore.Info.AppInfo
        let session: LoggerStore.Session? // Added: 3.5.7
    }

    struct Empty: Codable {
        public init() {}
    }

    struct PacketNetworkMessage {
        private struct Manifest: Codable {
            let messageSize: UInt32
            let requestBodySize: UInt32
            let responseBodySize: UInt32

            static let size = 12

            var totalSize: Int {
                Manifest.size + Int(messageSize) + Int(requestBodySize) + Int(responseBodySize)
            }
        }

        static func encode(_ event: LoggerStore.Event.NetworkTaskCompleted) throws -> Data {
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

        static func decode(_ data: Data) throws -> LoggerStore.Event.NetworkTaskCompleted {
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

            return LoggerStore.Event.NetworkTaskCompleted(taskId: event.taskId, taskType: event.taskType, createdAt: event.createdAt, originalRequest: event.originalRequest, currentRequest: event.currentRequest, response: event.response, error: event.error, requestBody: requestBody, responseBody: responseBody, metrics: event.metrics, label: event.label)
        }
    }
    
    struct Message {
        let url: URL
        let data: Data
        
        private struct Manifest: Codable {
            let urlSize: UInt32
            let dataSize: UInt32

            static let size = 8

            var totalSize: Int {
                Manifest.size + Int(urlSize) + Int(dataSize)
            }
        }

        static func encode(_ request: Message) throws -> Data {
            guard let url = request.url.absoluteString.data(using: .utf8) else {
                throw URLError(.unknown, userInfo: [:]) // Should never happen
            }
            var data = Data()
            data.append(Data(UInt32(url.count)))
            data.append(Data(UInt32(request.data.count)))
            data.append(url)
            data.append(request.data)
            return data
        }
        
        static func decode(_ data: Data) throws -> Message {
            guard data.count >= Manifest.size else {
                throw PacketParsingError.notEnoughData // Should never happen
            }
            let manifest = Manifest(
                urlSize: UInt32(data.from(0, size: 4)),
                dataSize: UInt32(data.from(4, size: 4))
            )
            guard data.count >= manifest.totalSize else {
                throw PacketParsingError.notEnoughData // This should never happen
            }
            guard let urlString = String(data: data.from(Manifest.size, size: Int(manifest.urlSize)), encoding: .utf8),
                  let url = URL(string: urlString) else {
                throw URLError(.badURL, userInfo: [:]) // This should never happen
            }
            let body = data.from(Manifest.size + Int(manifest.urlSize), size: Int(manifest.dataSize))
            return Message(url: url, data: body)
        }
    }

    struct GetMockRequest: Codable {
        let requestID: UUID
        let mockID: UUID
    }

    struct GetMockResponse: Codable {
        let requestID: UUID
        let mock: URLSessionMockedResponse
    }

    enum PacketParsingError: Error {
        case notEnoughData
        case unsupportedContentSize
    }
}

extension RemoteLogger.Connection {
    func send(code: RemoteLogger.PacketCode, data: Data) {
        send(code: code.rawValue, data: data)
    }

    func send<T: Encodable>(code: RemoteLogger.PacketCode, entity: T) {
        send(code: code.rawValue, entity: entity)
    }

    func send(code: RemoteLogger.PacketCode) {
        send(code: code.rawValue, entity: RemoteLogger.Empty())
    }
}

struct MockGetRequest {
    let id: UUID
}

struct URLSessionMock: Hashable, Codable {
    let mockID: UUID
    var pattern: String
    var method: String?
}

struct URLSessionMockedResponse: Codable {
    let errorCode: Int?
    let statusCode: Int?
    let headers: [String: String]?
    var body: String?
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

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Network
#if PULSE_STANDALONE_APP
import Pulse
#endif

struct URLSessionMockUpdateRequest: Codable {
    var update: [URLSessionMock]
    var delete: [UUID]
}

#warning("simplify how data is passed with fewer packet codes")
// - code (Int8)
// - header size (UInt32)
// - body size (UInt32)

#warning("add version of the protocol; should Pulse for Mac support previous version of the protocol (presumably yes)?")


// I see two options:
// a) the source of truth for mocks are on the client
//      pros: can in the future manage from clinet
// b) the source of truth for mocks is on the server
//      pros: supports two macs - one client scenario better; makes more sense
//      cons: how to implement this?

// When client connects to the remote server, the server sends the inital mock configuration to know what mocks to send and when. The same mock thing can be used for breakpoints.
// Don't call this breakpoint, but allow server to


// Gets headers/body for the given ID
struct MockGetRequest {
    let id: UUID
}

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

        // MARK: Mocks
        case updateMocks = 11 // URLSessionMockUpdateRequest
        case getMockedResponse = 12 // GetMockRequest / GetMockResponse
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
                throw PacketParsingError.notEnoughData
            }

            let manifest = Manifest(
                messageSize: UInt32(data.from(0, size: 4)),
                requestBodySize: UInt32(data.from(4, size: 4)),
                responseBodySize: UInt32(data.from(8, size: 4))
            )

            guard data.count >= manifest.totalSize else {
                throw PacketParsingError.notEnoughData
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

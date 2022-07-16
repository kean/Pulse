// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import Network

@available(iOS 14.0, tvOS 14.0, *)
extension RemoteLogger {
    enum PacketCode: UInt8 {
        case clientHello = 0 // PacketClientHello
        case serverHello = 1
        case pause = 2
        case resume = 3
        case storeMessage = 4 // Regular message
        case storeRequest = 5 // Network message (multipart data)
        case ping = 6

        var description: String {
            switch self {
            case .clientHello: return "PacketCode.clientHello"
            case .serverHello: return "PacketCode.serverHello"
            case .pause: return "PacketCode.pause"
            case .resume: return "PacketCode.resume"
            case .storeMessage: return "PacketCode.storeMessage"
            case .storeRequest: return "PacketCode.storeRequest"
            case .ping: return "PacketCode.ping"
            }
        }
    }

    struct PacketClientHello: Codable {
        let deviceId: UUID
        let deviceInfo: LoggerStoreInfo.DeviceInfo
        let appInfo: LoggerStoreInfo.AppInfo
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

        static func encode(_ message: LoggerStore.NetworkMessage) throws -> Data {
            var contents = [Data]()

            let strippedMessage = LoggerStore.NetworkMessage(createdAt: message.createdAt, request: message.request, response: message.response, error: message.error, requestBody: nil, responseBody: nil, metrics: message.metrics, urlSession: message.urlSession, session: message.session)
            let messageData = try JSONEncoder().encode(strippedMessage)
            contents.append(messageData)

            if let requestBody = message.requestBody, requestBody.count < Int32.max {
                contents.append(requestBody)
            }

            if let responseBody = message.responseBody, responseBody.count < Int32.max {
                contents.append(responseBody)
            }

            var data = Data()
            data.append(Data(UInt32(messageData.count)))
            data.append(Data(UInt32(message.requestBody?.count ?? 0)))
            data.append(Data(UInt32(message.responseBody?.count ?? 0)))
            for item in contents {
                data.append(item)
            }
            return data
        }

        static func decode(_ data: Data) throws -> LoggerStore.NetworkMessage {
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

            let message = try JSONDecoder().decode(
                LoggerStore.NetworkMessage.self,
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

            return LoggerStore.NetworkMessage(createdAt: message.createdAt, request: message.request, response: message.response, error: message.error, requestBody: requestBody, responseBody: responseBody, metrics: message.metrics, urlSession: message.urlSession, session: message.session)
        }
    }

    enum PacketParsingError: Error {
        case notEnoughData
        case unsupportedContentSize
    }
}

@available(iOS 14.0, tvOS 14.0, *)
extension RemoteLogger.Connection {
    func send(code: RemoteLogger.PacketCode, data: Data, _ completion: ((NWError?) -> Void)? = nil) {
        send(code: code.rawValue, data: data, completion)
    }

    func send<T: Encodable>(code: RemoteLogger.PacketCode, entity: T, _ completion: ((NWError?) -> Void)? = nil) {
        send(code: code.rawValue, entity: entity, completion)
    }

    func send(code: RemoteLogger.PacketCode, _ completion: ((NWError?) -> Void)? = nil) {
        send(code: code.rawValue, entity: RemoteLogger.Empty(), completion)
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

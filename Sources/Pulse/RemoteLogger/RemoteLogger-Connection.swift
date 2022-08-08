// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import Network

@available(iOS 14.0, tvOS 14.0, *)
public protocol RemoteLoggerConnectionDelegate: AnyObject {
    func connection(_ connection: RemoteLogger.Connection, didChangeState newState: NWConnection.State)
    func connection(_ connection: RemoteLogger.Connection, didReceiveEvent event: RemoteLogger.Connection.Event)
}

@available(iOS 14.0, tvOS 14.0, *)
extension RemoteLogger {
    public final class Connection {
        private let connection: NWConnection
        private var buffer = Data()

        public weak var delegate: RemoteLoggerConnectionDelegate?

        public convenience init(endpoint: NWEndpoint) {
            self.init(NWConnection(to: endpoint, using: .tcp))
        }

        public init(_ connection: NWConnection) {
            self.connection = connection
        }

        public func start(on queue: DispatchQueue) {
            connection.stateUpdateHandler = { [weak self] in
                guard let self = self else { return }
                self.delegate?.connection(self, didChangeState: $0)
            }
            receive()
            connection.start(queue: queue)
        }

        public enum Event {
            case packet(Packet)
            case error(Error)
            case completed
        }

        public struct Packet {
            public let code: UInt8
            public let body: Data
        }

        private func receive() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65535) { [weak self] data, _, isCompleted, error in
                guard let self = self else { return }
                if let data = data, !data.isEmpty {
                    self.process(data: data)
                }
                if isCompleted {
                    self.send(event: .completed)
                } else if let error = error {
                    self.send(event: .error(error))
                } else {
                    self.receive()
                }
            }
        }

        private func process(data freshData: Data) {
            guard !freshData.isEmpty else { return }

            var freshData = freshData
            if buffer.isEmpty {
                while let (packet, size) = decodePacket(from: freshData) {
                    send(event: .packet(packet))
                    if size == freshData.count {
                        return // No no processing needed
                    }
                    freshData.removeFirst(size)
                }
            }

            if !freshData.isEmpty {
                buffer.append(freshData)
                while let (packet, size) = decodePacket(from: buffer) {
                    send(event: .packet(packet))
                    buffer.removeFirst(size)
                }
                if buffer.count == 0 {
                    buffer = Data()
                }
            }
        }

        private func decodePacket(from data: Data) -> (Packet, Int)? {
            do {
                return try RemoteLogger.decode(buffer: data)
            } catch {
                if case .notEnoughData? = error as? PacketParsingError {
                    return nil
                }
                log("Unexpected error when processing a packet: \(error)")
                return nil
            }
        }

        private func send(event: Event) {
            delegate?.connection(self, didReceiveEvent: event)
        }

        public func send(code: UInt8, data: Data, _ completion: ((NWError?) -> Void)? = nil) {
            do {
                let data = try encode(code: code, body: data)
                connection.send(content: data, completion: .contentProcessed({ error in
                    if error != nil {
                        log("\(String(describing: error))")
                    }
                }))
            } catch {
                log("Failed to encode a packet: \(error)") // Should never happen
            }
        }

        public func send<T: Encodable>(code: UInt8, entity: T, _ completion: ((NWError?) -> Void)? = nil) {
            do {
                let data = try JSONEncoder().encode(entity)
                send(code: code, data: data, completion)
            } catch {
                log("Failed to encode a packet: \(error)") // Should never happen
            }
        }

        public func cancel() {
            connection.cancel()
        }
    }
}

// MARK: Helpers

@available(iOS 14.0, tvOS 14.0, *)
extension RemoteLogger {
    static func encode(code: UInt8, body: Data) throws -> Data {
        guard body.count < UInt32.max else {
            throw PacketParsingError.unsupportedContentSize
        }

        var data = Data()
        data.append(code)
        let body = try body.compressed()
        data.append(Data(UInt32(body.count)))
        data.append(body)
        return data
    }

    static func decode(buffer: Data) throws -> (Connection.Packet, Int) {
        let header = try PacketHeader(data: buffer)
        guard buffer.count >= header.compressedPacketLength else {
            throw PacketParsingError.notEnoughData
        }
        let body = buffer.from(header.contentOffset, size: Int(header.contentSize))
        let packet = Connection.Packet(code: header.code, body: try body.decompressed())
        return (packet, header.compressedPacketLength)
    }

    /// |code|contentSize|body?|
    struct PacketHeader {
        let code: UInt8
        let contentSize: UInt32

        var compressedPacketLength: Int { Int(PacketHeader.size + contentSize) }
        var contentOffset: Int { Int(PacketHeader.size) }

        static let size: UInt32 = 5

        init(code: UInt8, contentSize: UInt32) {
            self.code = code
            self.contentSize = contentSize
        }

        init(data: Data) throws {
            guard data.count >= PacketHeader.size else {
                throw PacketParsingError.notEnoughData
            }
            self.code = data[data.startIndex]
            self.contentSize = UInt32(data.from(1, size: 4))
        }
    }
}

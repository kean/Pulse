// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Network
import CryptoKit
import OSLog

#if PULSE_STANDALONE_APP
import Pulse
#endif

protocol RemoteLoggerConnectionDelegate: AnyObject {
    func connection(_ connection: RemoteLogger.Connection, didChangeState newState: NWConnection.State)
    func connection(_ connection: RemoteLogger.Connection, didReceiveEvent event: RemoteLogger.Connection.Event)
}

extension RemoteLogger {
    final class Connection {
        var endpoint: NWEndpoint { connection.endpoint }
        private let connection: NWConnection
        private var buffer = Data()
        private var id: UInt32 = 0
        private var handlers: [UInt32: (Data?, Error?) -> Void] = [:]
        private let log: OSLog

        weak var delegate: RemoteLoggerConnectionDelegate?

        convenience init(endpoint: NWEndpoint, using parameters: NWParameters) {
            self.init(NWConnection(to: endpoint, using: parameters))
        }

        init(_ connection: NWConnection) {
            self.connection = connection

            let isLogEnabled = UserDefaults.standard.bool(forKey: "com.github.kean.pulse.debug")
            self.log = isLogEnabled ? OSLog(subsystem: "com.github.kean.pulse", category: "RemoteLogger") : .disabled
        }

        func start(on queue: DispatchQueue) {
            connection.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.delegate?.connection(self, didChangeState: state)
                }
            }
            receive()
            connection.start(queue: queue)
        }

        enum Event {
            case packet(Packet)
            case error(Error)
            case completed
        }

        struct Packet {
            let code: UInt8
            let body: Data
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
                os_log("Unexpected error when processing a packet: %{public}@", log: log, type: .error, "\(error)")
                return nil
            }
        }

        private func send(event: Event) {
            // If it's a response for a message, pass it to the registered handler.
            // Otherwise, send it to the delegate as a new message.
            if case .packet(let packet) = event,
               packet.code == RemoteLogger.PacketCode.message.rawValue,
               let header = Message.Header(packet.body),
               header.options.contains(.response),
               let handler = handlers.removeValue(forKey: header.id) {
                handler(try? Message.decode(packet.body).data, nil)
            } else {
                DispatchQueue.main.async {
                    self.delegate?.connection(self, didReceiveEvent: event)
                }
            }
        }
        
        func send(code: UInt8, data: Data) {
            do {
                let data = try encode(code: code, body: data)
                let log = self.log
                connection.send(content: data, completion: .contentProcessed({ error in
                    if let error {
                        os_log("Failed to send data: %{public}@", log: log, type: .error, "\(error)")
                    }
                }))
            } catch {
                os_log("Failed to encode a packet: %{public}@", log: log, type: .error, "\(error)")
            }
        }

        func send<T: Encodable>(code: UInt8, entity: T) {
            do {
                let data = try JSONEncoder().encode(entity)
                send(code: code, data: data)
            } catch {
                os_log("Failed to encode a packet: %{public}@", log: log, type: .error, "\(error)")
            }
        }
    
        func sendMessage<T: Encodable>(path: Path, entity: T, _ completion: ((Data?, Error?) -> Void)? = nil) {
            do {
                sendMessage(path: path, data: try JSONEncoder().encode(entity), completion)
            } catch {
                os_log("Failed to send a message: %{public}@", log: log, type: .error, "\(error)")
            }
        }
        
        func sendMessage(path: Path, data: Data? = nil, _ completion: ((Data?, Error?) -> Void)? = nil) {
            let message = Message(id: id, options: [], path: path, data: data ?? Data())
            
            if id == UInt32.max {
                id = 0
            } else {
                id += 1
            }
            
            if let completion = completion {
                let id = message.id
                handlers[message.id] = completion
                connection.queue?.asyncAfter(deadline: .now() + .seconds(20)) { [weak self] in
                    if let handler = self?.handlers.removeValue(forKey: id) {
                        handler(nil, URLError(.timedOut))
                    }
                }
            }
            
            do {
                let data = try Message.encode(message)
                send(code: .message, data: data)
            } catch {
                os_log("Failed to send a message: %{public}@", log: log, type: .error, "\(error)")
            }
        }

        func sendResponse<T: Encodable>(for message: Message, entity: T) {
            do {
                sendResponse(for: message, data: try JSONEncoder().encode(entity))
            } catch {
                os_log("Failed to encode a response: %{public}@", log: log, type: .error, "\(error)")
            }
        }
        
        func sendResponse(for message: Message, data: Data) {
            let message = Message(id: message.id, options: [.response], path: message.path, data: data)
            do {
                let data = try Message.encode(message)
                send(code: .message, data: data)
            } catch {
                os_log("Failed to encode a response: %{public}@", log: log, type: .error, "\(error)")
            }
        }
        
        func cancel() {
            connection.cancel()
        }
    }
}

// MARK: Helpers

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

extension NWParameters {
    convenience init(passcode: String) {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 4

        self.init(tls: NWParameters.tlsOptions(passcode: passcode), tcp: tcpOptions)

        self.includePeerToPeer = true
    }

    // Create TLS options using a passcode to derive a preshared key.
    private static func tlsOptions(passcode: String) -> NWProtocolTLS.Options {
        let tlsOptions = NWProtocolTLS.Options()

        let authenticationKey = SymmetricKey(data: passcode.data(using: .utf8)!)
        var authenticationCode = HMAC<SHA256>.authenticationCode(for: "PulseLoggerProtocol".data(using: .utf8)!, using: authenticationKey)
        let authenticationDispatchData = withUnsafeBytes(of: &authenticationCode) { (pointer: UnsafeRawBufferPointer) in
            DispatchData(bytes: pointer)
        }
        sec_protocol_options_add_pre_shared_key(
            tlsOptions.securityProtocolOptions,
            authenticationDispatchData as __DispatchData,
            DispatchData.make(string: "PulseLoggerProtocol") as __DispatchData
        )
        sec_protocol_options_append_tls_ciphersuite(
            tlsOptions.securityProtocolOptions,
            tls_ciphersuite_t(rawValue: UInt16(TLS_PSK_WITH_AES_128_GCM_SHA256))!
        )
        return tlsOptions
    }
}

extension DispatchData {
    static func make(string: String) -> DispatchData {
        let data = string.data(using: .unicode) ?? Data()
        return Swift.withUnsafeBytes(of: data) { (pointer: UnsafeRawBufferPointer) in
            DispatchData(bytes: UnsafeRawBufferPointer(start: pointer.baseAddress, count: data.count))
        }
    }
}

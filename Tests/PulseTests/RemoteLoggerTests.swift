// The MIT License (MIT)
//
// Copyright (c) 2020-2022 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import CoreData
@testable import Pulse

final class RemoteLoggerTests: XCTestCase {
    func testEncodeNetworkMessage() throws {
        // GIVEN
        let event = LoggerStore.Event.NetworkTaskCompleted(
            taskId: UUID(),
            taskType: .dataTask,
            createdAt: Date(),
            originalRequest: NetworkLogger.Request(MockDataTask.login.request),
            currentRequest: NetworkLogger.Request(MockDataTask.login.request),
            response: NetworkLogger.Response(MockDataTask.login.response),
            error: nil,
            requestBody: "hello".data(using: .utf8)!,
            responseBody: MockDataTask.login.responseBody,
            metrics: MockDataTask.login.metrics,
            sessionID: 0
        )

        // WHEN
        let decoded: LoggerStore.Event.NetworkTaskCompleted = try benchmark(title: "encode/decode") {
            // Encode packed
            let payload = try RemoteLogger.PacketNetworkMessage.encode(event)
            let sentPacket = try RemoteLogger.encode(code: RemoteLogger.PacketCode.storeEventNetworkTaskCompleted.rawValue, body: payload)
            // Decode packet
            print("Packet length: \(sentPacket.count) bytes")
            let (packet, _) = try RemoteLogger.decode(buffer: sentPacket)
            XCTAssertEqual(packet.code, RemoteLogger.PacketCode.storeEventNetworkTaskCompleted.rawValue)
            return try RemoteLogger.PacketNetworkMessage.decode(packet.body)
        }

        // THEN
        XCTAssertEqual(decoded.taskId, event.taskId)
        XCTAssertEqual(decoded.taskType, event.taskType)
        XCTAssertEqual(decoded.createdAt, event.createdAt)
        XCTAssertEqual(decoded.originalRequest.url, event.originalRequest.url)
        XCTAssertEqual(decoded.requestBody, "hello".data(using: .utf8))
        XCTAssertEqual(decoded.responseBody, event.responseBody)
        XCTAssertEqual(decoded.metrics?.totalTransferSize.totalBytesSent, event.metrics?.totalTransferSize.totalBytesSent)
        XCTAssertEqual(decoded.sessionID, event.sessionID)
    }
}

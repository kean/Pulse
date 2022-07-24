// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData

/// The events used for syncing data between stores.
public enum LoggerStoreEvent {
    case messageStored(MessageCreated)
    case networkTaskCreated(NetworkTaskCreated)
    case networkTaskProgressUpdated(NetworkTaskProgressUpdated)
    case networkTaskCompleted(NetworkTaskCompleted)

    public final class MessageCreated: Codable {
        public let createdAt: Date
        public let label: String
        public let level: LoggerStore.Level
        public let message: String
        public let metadata: [String: String]?
        public let session: String
        public let file: String
        public let function: String
        public let line: UInt

        public init(createdAt: Date, label: String, level: LoggerStore.Level, message: String, metadata: [String: String]?, session: String, file: String, function: String, line: UInt) {
            self.createdAt = createdAt
            self.label = label
            self.level = level
            self.message = message
            self.metadata = metadata
            self.session = session
            self.file = file
            self.function = function
            self.line = line
        }
    }

    public struct NetworkTaskCreated: Codable {
        public let taskId: UUID
        public let taskType: NetworkLoggerTaskType
        public let createdAt: Date
        public let originalRequest: NetworkLoggerRequest
        public let currentRequest: NetworkLoggerRequest?
        public var requestBody: Data?
        public let session: String

        public init(taskId: UUID, taskType: NetworkLoggerTaskType, createdAt: Date, originalRequest: NetworkLoggerRequest, currentRequest: NetworkLoggerRequest?, requestBody: Data?, session: String) {
            self.taskId = taskId
            self.taskType = taskType
            self.createdAt = createdAt
            self.originalRequest = originalRequest
            self.currentRequest = currentRequest
            self.requestBody = requestBody
            self.session = session
        }
    }

    public struct NetworkTaskProgressUpdated: Codable {
        public let taskId: UUID
        public let completedUnitCount: Int64
        public let totalUnitCount: Int64

        public init(taskId: UUID, completedUnitCount: Int64, totalUnitCount: Int64) {
            self.taskId = taskId
            self.completedUnitCount = completedUnitCount
            self.totalUnitCount = totalUnitCount
        }
    }

    public final class NetworkTaskCompleted: Codable {
        public let taskId: UUID
        public let taskType: NetworkLoggerTaskType
        public let createdAt: Date
        public let originalRequest: NetworkLoggerRequest
        public let currentRequest: NetworkLoggerRequest?
        public let response: NetworkLoggerResponse?
        public let error: NetworkLoggerError?
        public let requestBody: Data?
        public let responseBody: Data?
        public let metrics: NetworkLoggerMetrics?
        public let completedUnitCount: Int64
        public let totalUnitCount: Int64
        public let session: String

        public init(taskId: UUID, taskType: NetworkLoggerTaskType, createdAt: Date, originalRequest: NetworkLoggerRequest, currentRequest: NetworkLoggerRequest?, response: NetworkLoggerResponse?, error: NetworkLoggerError?, requestBody: Data?, responseBody: Data?, metrics: NetworkLoggerMetrics?, completedUnitCount: Int64, totalUnitCount: Int64, session: String) {
            self.taskId = taskId
            self.taskType = taskType
            self.createdAt = createdAt
            self.originalRequest = originalRequest
            self.currentRequest = currentRequest
            self.response = response
            self.error = error
            self.requestBody = requestBody
            self.responseBody = responseBody
            self.metrics = metrics
            self.completedUnitCount = completedUnitCount
            self.totalUnitCount = totalUnitCount
            self.session = session
        }
    }
}

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation

extension LoggerStore {
    /// The events used for syncing data between stores.
    @frozen public enum Event: Sendable {
        case messageStored(MessageCreated)
        case networkTaskCreated(NetworkTaskCreated)
        case networkTaskProgressUpdated(NetworkTaskProgressUpdated)
        case networkTaskCompleted(NetworkTaskCompleted)

        public struct MessageCreated: Codable, Sendable {
            public var createdAt: Date
            public var label: String
            public var level: LoggerStore.Level
            public var message: String
            public var metadata: [String: String]?
            public var session: UUID
            public var file: String
            public var function: String
            public var line: UInt

            public init(createdAt: Date, label: String, level: LoggerStore.Level, message: String, metadata: [String: String]?, session: UUID, file: String, function: String, line: UInt) {
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

        public struct NetworkTaskCreated: Codable, Sendable {
            public var taskId: UUID
            public var taskType: NetworkLogger.TaskType
            public var createdAt: Date
            public var originalRequest: NetworkLogger.Request
            public var currentRequest: NetworkLogger.Request?
            public var session: UUID

            public init(taskId: UUID, taskType: NetworkLogger.TaskType, createdAt: Date, originalRequest: NetworkLogger.Request, currentRequest: NetworkLogger.Request?, session: UUID) {
                self.taskId = taskId
                self.taskType = taskType
                self.createdAt = createdAt
                self.originalRequest = originalRequest
                self.currentRequest = currentRequest
                self.session = session
            }
        }

        public struct NetworkTaskProgressUpdated: Codable, Sendable {
            public var taskId: UUID
            public var url: URL?
            public var completedUnitCount: Int64
            public var totalUnitCount: Int64

            public init(taskId: UUID, url: URL?, completedUnitCount: Int64, totalUnitCount: Int64) {
                self.taskId = taskId
                self.url = url
                self.completedUnitCount = completedUnitCount
                self.totalUnitCount = totalUnitCount
            }
        }

        public struct NetworkTaskCompleted: Codable, Sendable {
            public var taskId: UUID
            public var taskType: NetworkLogger.TaskType
            public var createdAt: Date
            public var originalRequest: NetworkLogger.Request
            public var currentRequest: NetworkLogger.Request?
            public var response: NetworkLogger.Response?
            public var error: NetworkLogger.ResponseError?
            public var requestBody: Data?
            public var responseBody: Data?
            public var metrics: NetworkLogger.Metrics?
            public var session: UUID

            public init(taskId: UUID, taskType: NetworkLogger.TaskType, createdAt: Date, originalRequest: NetworkLogger.Request, currentRequest: NetworkLogger.Request?, response: NetworkLogger.Response?, error: NetworkLogger.ResponseError?, requestBody: Data?, responseBody: Data?, metrics: NetworkLogger.Metrics?, session: UUID) {
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
                self.session = session
            }
        }

        var url: URL? {
            switch self {
            case .messageStored:
                return nil
            case .networkTaskCreated(let event):
                return event.originalRequest.url
            case .networkTaskProgressUpdated(let event):
                return event.url
            case .networkTaskCompleted(let event):
                return event.originalRequest.url
            }
        }
    }
}

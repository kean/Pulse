// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData

private enum HARDateFormatter {
    static var formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withFullTime]
        return formatter
    }()
}

enum HARDocument {
    /// Writes the network tasks associated with the given entities as a HAR
    /// document.
    ///
    /// The entries are encoded and written one at a time, so only a single
    /// request and response body are kept in memory regardless of the number
    /// of tasks.
    ///
    /// - important: Must be called on the queue of the given context.
    ///
    /// - returns: The size of the written document.
    static func write(_ objectIDs: [NSManagedObjectID], context: NSManagedObjectContext, to url: URL) throws -> Int64 {
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        let encoder = JSONEncoder()
        var pages: [Page] = []
        var pageIDs: [String: String] = [:]
        var writtenTaskIDs = Set<NSManagedObjectID>()

        try handle.write(contentsOf: Data(#"{"log":{"version":"1.2","creator":{"name":"Pulse HAR generation tool","version":"0.1"},"entries":["#.utf8))
        for objectID in objectIDs {
            try autoreleasepool {
                // A task and the message it is attached to resolve to the same entry.
                guard let object = try? context.existingObject(with: objectID),
                      let task = LoggerEntity(object).task,
                      writtenTaskIDs.insert(task.objectID).inserted else {
                    return
                }
                let title = task.url ?? ""
                let pageId: String
                if let id = pageIDs[title] {
                    pageId = id
                } else {
                    pageId = "page_\(pages.count)"
                    pageIDs[title] = pageId
                    pages.append(.init(
                        id: pageId,
                        startedDateTime: HARDateFormatter.formatter.string(from: task.createdAt),
                        title: title
                    ))
                }
                let entry = try encoder.encode(Entry(entity: task, pageId: pageId))
                if writtenTaskIDs.count > 1 {
                    try handle.write(contentsOf: Data(",".utf8))
                }
                try handle.write(contentsOf: entry)
                context.refresh(task, mergeChanges: false)
                context.refresh(object, mergeChanges: false)
            }
        }
        try handle.write(contentsOf: Data(#"],"pages":"#.utf8))
        try handle.write(contentsOf: encoder.encode(pages))
        try handle.write(contentsOf: Data("}}".utf8))
        return Int64(try handle.offset())
    }
}

extension HARDocument {
    struct Page: Encodable {
        let id: String
        let pageTimings: PageTimings
        let startedDateTime: String?
        let title: String

        init(
            id: String,
            pageTimings: PageTimings = .init(),
            startedDateTime: String,
            title: String
        ) {
            self.id = id
            self.pageTimings = pageTimings
            self.startedDateTime = startedDateTime
            self.title = title
        }
    }

    struct Entry: Encodable {
        let cache: Cache
        let connection: String
        let pageref: String
        let request: Request
        let response: Response?
        let serverIPAddress: String
        let startedDateTime: String
        let time: Double
        let timings: Timings?

        init(entity: NetworkTaskEntity, pageId: String) {
            cache = .init()
            connection = "\(entity.orderedTransactions.first?.remotePort ?? .zero)"
            pageref = pageId
            request = .init(entity)
            response = .init(entity)

            serverIPAddress = entity.orderedTransactions.first?.remoteAddress ?? ""
            startedDateTime = HARDateFormatter.formatter.string(from: entity.createdAt)
            time = entity.duration * 1000
            timings = .init(entity.orderedTransactions.last?.timing)
        }
    }

    struct Timings: Encodable {
        let blocked: Double
        let connect: Int
        let dns: Int
        let receive: Double
        let send: Double
        let ssl: Int
        let wait: Double

        init?(_ timing: NetworkLogger.TransactionTimingInfo?) {
            if let timing {
                blocked = -1
                connect = Self.millisecondsBetween(
                    startDate: timing.fetchStartDate,
                    endDate: timing.connectEndDate
                )

                dns = Self.millisecondsBetween(
                    startDate: timing.domainLookupStartDate,
                    endDate: timing.domainLookupEndDate
                )

                receive = Self.intervalBetween(
                    startDate: timing.responseStartDate,
                    endDate: timing.responseEndDate
                )

                send = Self.intervalBetween(
                    startDate: timing.requestStartDate,
                    endDate: timing.requestEndDate
                )

                ssl = Self.millisecondsBetween(
                    startDate: timing.secureConnectionStartDate,
                    endDate: timing.secureConnectionEndDate
                )

                wait = timing.duration ?? .zero
            } else {
                return nil
            }
        }
    }

    struct PageTimings: Encodable {
        let onContentLoad: Int
        let onLoad: Int

        init(
            onContentLoad: Int = -1,
            onLoad: Int = -1
        ) {
            self.onContentLoad = onContentLoad
            self.onLoad = onLoad
        }
    }
}

extension HARDocument.Entry {
    struct Request: Encodable {
        var bodySize: Int = -1
        let cookies: [[String: String]]
        let headers: [[String: String]]
        let httpVersion: String
        let method: String?
        let queryString: [[String: String]]
        let url: String?
        let postData: Content?
       
        init(_ entity: NetworkTaskEntity?) {
            
            bodySize = Int(entity?.requestBody?.size ?? -1);
            cookies = []
            headers = entity?.originalRequest?.headers.compactMap { ["name": $0.key, "value": $0.value] } ?? [];
            httpVersion = "HTTP/2";
            method = entity?.httpMethod;
            queryString = [];
            url = entity?.url;
            postData = .init(entity?.requestBody);
            
        }
        
    }

    struct Response: Encodable {
        let bodySize: Int
        let content: Content?
        let cookies: [[String: String]]
        let headers: [[String: String]]
        let headersSize: Int
        let httpVersion: String
        let redirectURL: String
        let status: Int
        var statusText: String

        init?(_ entity: NetworkTaskEntity?) {
            if let entity {
                bodySize = Int(entity.responseBody?.size ?? -1)
                content = .init(entity.responseBody)
                cookies = []
                headers = entity.response?.headers.compactMap { ["name": $0.key, "value": $0.value] } ?? []
                headersSize = -1
                httpVersion = "HTTP/2"
                redirectURL = ""
                status = Int(entity.statusCode)
                statusText = ""
            } else {
                return nil
            }
        }
    }

    struct Content: Encodable {
        let compression: Int
        let encoding: String?
        let mimeType: String
        let size: Int
        var text: String = ""

        init?(_ entity: LoggerBlobHandleEntity?) {
            if let entity {
                compression = Int(entity.size - entity.decompressedSize)
                encoding = ""
                mimeType = entity.contentType?.rawValue ?? ""
                size = entity.data?.count ?? .zero
                if let data = entity.data {
                    text = String(decoding: data, as: UTF8.self)
                }
            } else {
                return nil
            }
        }
    }

    struct Cache: Encodable {
        let afterRequest: Item?
        let beforeRequest: Item?

        init(
            afterRequest: Item? = nil,
            beforeRequest: Item? = nil
        ) {
            self.afterRequest = afterRequest
            self.beforeRequest = beforeRequest
        }
    }
}

extension HARDocument.Entry.Cache {
    struct Item: Encodable {
        let eTag: String
        let expires: String
        let hitCount: Int
        let lastAccess: String

        init(
            eTag: String = "",
            expires: String = "",
            hitCount: Int = .zero,
            lastAccess: String = ""
        ) {
            self.eTag = eTag
            self.expires = expires
            self.hitCount = hitCount
            self.lastAccess = lastAccess
        }
    }
}

// MARK: - Helper Methods

extension HARDocument.Timings {
    fileprivate static func millisecondsBetween(startDate: Date?, endDate: Date?) -> Int {
        let timeInterval = intervalBetween(startDate: startDate, endDate: endDate)
        guard timeInterval != .zero else {
            // return -1 if value can not be determined as indicated on HAR document specs.
            return -1
        }
        return Int(timeInterval * 1000)
    }

    fileprivate static func intervalBetween(startDate: Date?, endDate: Date?) -> TimeInterval {
        guard let startDate, let endDate else {
            return .zero
        }
        return endDate.timeIntervalSince(startDate)
    }
}

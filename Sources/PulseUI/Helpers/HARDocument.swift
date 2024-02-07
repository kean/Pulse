//
//  HARDocument.swift
//  PulseUI
//
//  Created by Jota Uribe on 6/02/24.
//  Copyright © 2024 kean. All rights reserved.
//

import Foundation
import Pulse

fileprivate enum HARDateFormatter {
    static var formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withFullTime]
        return formatter
    }()
}

struct HARDocument: Encodable {
    private let log: Log
    init(store: LoggerStore) throws {
        var entries: [Entry] = []
        var pages: [Page] = []
        try Dictionary(grouping: store.allTasks(), by: \.url).values.forEach { networkTasks in
            let pageId = "page_\(pages.count)"
            pages.append(
                .init(
                    id: pageId,
                    startedDateTime: HARDateFormatter.formatter.string(from: networkTasks[.zero].createdAt),
                    title: networkTasks[.zero].url ?? ""
                )
            )
            entries.append(contentsOf: networkTasks.map { .init(entity: $0, pageId: pageId) })
        }
        try store.allMessages().forEach { message in
            if let task = message.task {
                entries.append(.init(entity: task, pageId: "page_\(pages.count)"))
            }
        }
        log = .init(
            version: "1.2",
            creator: ["name": "Pulse HAR generation tool", "version": "0.1"],
            pages: pages,
            entries: entries
        )
    }
}

extension HARDocument {
    struct Log: Encodable {
        let version: String
        let creator: [String: String]
        var pages: [Page]
        var entries: [Entry]
    }
    
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
            request = .init(
                cookies: [],
                headers: entity.originalRequest?.headers.compactMap { ["name": $0.key, "value": $0.value] } ?? [],
                httpVersion: "HTTP/2",
                method: entity.httpMethod,
                queryString: [],
                url: entity.url
            )
            
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

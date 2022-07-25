// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

extension KeyValueSectionViewModel {
    static func makeSummary(for request: NetworkLoggerRequest) -> KeyValueSectionViewModel {
        let components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        var items: [(String, String?)] = []
        items += [
            ("URL", request.url?.absoluteString),
            ("Method", request.httpMethod)
        ]
        if let host = components?.host {
            items.append(("Host", host))
        }
        if let path = components?.path {
            items.append(("Path", path))
        }
        return KeyValueSectionViewModel(
            title: "Request Summary",
            color: .blue,
            items: items
        )
    }

    static func makeParameters(for request: NetworkLoggerRequest) -> KeyValueSectionViewModel {
        KeyValueSectionViewModel(title: "Request Parameters", color: .gray, items: [
            ("Cache Policy", URLRequest.CachePolicy(rawValue: request.cachePolicy).map { $0.description }),
            ("Timeout Interval", DurationFormatter.string(from: request.timeoutInterval)),
            ("Allows Cellular Access", request.allowsCellularAccess.description),
            ("Allows Expensive Network Access", request.allowsExpensiveNetworkAccess.description),
            ("Allows Constrained Network Access", request.allowsConstrainedNetworkAccess.description),
            ("HTTP Should Handle Cookies", request.httpShouldHandleCookies.description),
            ("HTTP Should Use Pipelining", request.httpShouldUsePipelining.description)
        ])
    }

    static func makeRequestHeaders(for headers: [String: String], action: @escaping () -> Void) -> KeyValueSectionViewModel {
        KeyValueSectionViewModel(
            title: "Request Headers",
            color: .blue,
            action: headers.isEmpty ? nil : ActionViewModel(action: action,title: "View"),
            items: headers.sorted(by: { $0.key < $1.key })
        )
    }

    static func makeSummary(for response: NetworkLoggerResponse) -> KeyValueSectionViewModel {
        KeyValueSectionViewModel(title: "Response Summary", color: .indigo, items: [
            ("Status Code", response.statusCode.map { String($0) }),
            ("Content Type", response.contentType),
            ("Expected Content Length", response.expectedContentLength.map { ByteCountFormatter.string(fromByteCount: max(0, $0), countStyle: .file) })
        ])
    }

    static func makeResponseHeaders(for headers: [String: String], action: @escaping () -> Void) -> KeyValueSectionViewModel {
        KeyValueSectionViewModel(
            title: "Response Headers",
            color: .indigo,
            action: headers.isEmpty ? nil : ActionViewModel(action: action, title: "View"),
            items: headers.sorted(by: { $0.key < $1.key })
        )
    }

    static func makeTiming(for transaction: NetworkLoggerTransactionMetrics) -> KeyValueSectionViewModel {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss.SSS"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.doesRelativeDateFormatting = true

        var startDate: Date?
        var items: [(String, String?)] = []
        func addDate(_ date: Date?, title: String) {
            guard let date = date else { return }
            if items.isEmpty {
                startDate = date
                items.append(("Date", dateFormatter.string(from: date)))
            }
            var value = timeFormatter.string(from: date)
            if let startDate = startDate, startDate != date {
                let duration = date.timeIntervalSince(startDate)
                value += " (+\(DurationFormatter.string(from: duration)))"
            }
            items.append((title, value))
        }
        addDate(transaction.fetchStartDate, title: "Fetch Start")
        addDate(transaction.domainLookupStartDate, title: "Domain Lookup Start")
        addDate(transaction.domainLookupEndDate, title: "Domain Lookup End")
        addDate(transaction.connectStartDate, title: "Connect Start")
        addDate(transaction.secureConnectionStartDate, title: "Secure Connect Start")
        addDate(transaction.secureConnectionEndDate, title: "Secure Connect End")
        addDate(transaction.connectEndDate, title: "Connect End")
        addDate(transaction.requestStartDate, title: "Request Start")
        addDate(transaction.requestEndDate, title: "Request End")
        addDate(transaction.responseStartDate, title: "Response Start")
        addDate(transaction.responseEndDate, title: "Response End")

        return KeyValueSectionViewModel(title: "Timing", color: .orange, items: items)
    }

    static func makeErrorDetails(for error: NetworkLoggerError, action: @escaping () -> Void) -> KeyValueSectionViewModel {
        KeyValueSectionViewModel(
            title: "Error",
            color: .red,
            action: ActionViewModel(action: action, title: "View"),
            items: [
                ("Domain", error.domain),
                ("Code", descriptionForError(domain: error.domain, code: error.code)),
                ("Message", error.localizedDescription)
            ])
    }

    static func makeQueryItems(for url: URL, action: @escaping () -> Void) -> KeyValueSectionViewModel? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems, !queryItems.isEmpty else {
            return nil
        }
        return KeyValueSectionViewModel(
            title: "Query Items",
            color: .blue,
            action: ActionViewModel(action: action, title: "View"),
            items: queryItems.map { ($0.name, $0.value) }
        )
    }
}

private func descriptionForError(domain: String, code: Int) -> String {
    guard domain == NSURLErrorDomain else {
        return "\(code)"
    }
    return "\(code) (\(descriptionForURLErrorCode(code)))"
}

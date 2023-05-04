// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct KeyValueSectionViewModel {
    var title: String
    var color: Color
    var items: [(String, String?)] = []
}

extension KeyValueSectionViewModel {
    static func makeParameters(for request: NetworkRequestEntity) -> KeyValueSectionViewModel {
        var items: [(String, String?)] = [
            ("Cache Policy", request.cachePolicy.description),
            ("Timeout Interval", DurationFormatter.string(from: TimeInterval(request.timeoutInterval), isPrecise: false))
        ]
        // Display only non-default values
        if !request.allowsCellularAccess {
            items.append(("Allows Cellular Access", request.allowsCellularAccess.description))
        }
        if !request.allowsExpensiveNetworkAccess {
            items.append(("Allows Expensive Network Access", request.allowsExpensiveNetworkAccess.description))
        }
        if !request.allowsConstrainedNetworkAccess {
            items.append(("Allows Constrained Network Access", request.allowsConstrainedNetworkAccess.description))
        }
        if !request.httpShouldHandleCookies {
            items.append(("Should Handle Cookies", request.httpShouldHandleCookies.description))
        }
        if request.httpShouldUsePipelining {
            items.append(("HTTP Should Use Pipelining", request.httpShouldUsePipelining.description))
        }
        return KeyValueSectionViewModel(title: "Options", color: .indigo, items: items)
    }

    static func makeTaskDetails(for task: NetworkTaskEntity) -> KeyValueSectionViewModel {
        func format(size: Int64) -> String {
            size > 0 ? ByteCountFormatter.string(fromByteCount: size) : "Empty"
        }
        let taskType = task.type?.urlSessionTaskClassName ?? "URLSessionDataTask"
        return KeyValueSectionViewModel(title: taskType, color: .primary, items: [
            ("Host", task.url.flatMap(URL.init)?.host),
            ("Date", task.startDate.map(DateFormatter.fullDateFormatter.string)),
            ("Duration", task.duration > 0 ? DurationFormatter.string(from: task.duration) : nil)
        ])
    }

    static func makeComponents(for url: URL) -> KeyValueSectionViewModel? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        return KeyValueSectionViewModel(
            title: "URL Components",
            color: .blue,
            items: [
                ("Scheme", components.scheme),
                ("Port", components.port?.description),
                ("User", components.user),
                ("Password", components.password),
                ("Host", components.host),
                ("Path", components.path),
                ("Query", components.query),
                ("Fragment", components.fragment)
            ].filter { $0.1?.isEmpty == false })
    }

    static func makeHeaders(title: String, headers: [String: String]?) -> KeyValueSectionViewModel {
        KeyValueSectionViewModel(
            title: title,
            color: .red,
            items: (headers ?? [:]).sorted {
                // Display cookies last because they typically take too much space
                $1.key.lowercased().contains("cookies") || $0.key < $1.key
            }
        )
    }

    static func makeErrorDetails(for task: NetworkTaskEntity) -> KeyValueSectionViewModel? {
        guard task.errorCode != 0, task.state == .failure else {
            return nil
        }
        return KeyValueSectionViewModel(
            title: "Error",
            color: .red,
            items: [
                ("Domain", task.errorDomain),
                ("Code", descriptionForError(domain: task.errorDomain, code: task.errorCode)),
                ("Description", task.errorDebugDescription)
            ])
    }

    private static func descriptionForError(domain: String?, code: Int32) -> String {
        guard domain == NSURLErrorDomain else {
            return "\(code)"
        }
        return "\(code) (\(descriptionForURLErrorCode(Int(code))))"
    }

    static func makeQueryItems(for url: URL) -> KeyValueSectionViewModel? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              !queryItems.isEmpty else {
            return nil
        }
        return makeQueryItems(for: queryItems)
    }

    static func makeQueryItems(for queryItems: [URLQueryItem]) -> KeyValueSectionViewModel? {
        KeyValueSectionViewModel(
            title: "Query",
            color: .purple,
            items: queryItems.map { ($0.name, $0.value) }
        )
    }

    static func makeDetails(for transaction: NetworkTransactionMetricsEntity) -> [KeyValueSectionViewModel] {
        return [
            makeTiming(for: transaction),
            makeTransferSection(for: transaction),
            makeProtocolSection(for: transaction),
            makeMiscSection(for: transaction),
            makeSecuritySection(for: transaction)
        ].compactMap { $0 }
    }

    private static func makeTiming(for transaction: NetworkTransactionMetricsEntity) -> KeyValueSectionViewModel {
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US")
        timeFormatter.dateFormat = "hh:mm:ss.SSS"

        var startDate: Date?
        var items: [(String, String?)] = []
        func addDate(_ date: Date?, title: String) {
            guard let date = date else { return }
            if items.isEmpty {
                startDate = date
            }
            var value = timeFormatter.string(from: date)
            if let startDate = startDate, startDate != date {
                let duration = date.timeIntervalSince(startDate)
                value += " (+\(DurationFormatter.string(from: duration)))"
            }
            items.append((title, value))
        }
        let timing = transaction.timing
        addDate(timing.fetchStartDate, title: "Fetch Start")
        addDate(timing.domainLookupStartDate, title: "Domain Lookup Start")
        addDate(timing.domainLookupEndDate, title: "Domain Lookup End")
        addDate(timing.connectStartDate, title: "Connect Start")
        addDate(timing.secureConnectionStartDate, title: "Secure Connect Start")
        addDate(timing.secureConnectionEndDate, title: "Secure Connect End")
        addDate(timing.connectEndDate, title: "Connect End")
        addDate(timing.requestStartDate, title: "Request Start")
        addDate(timing.requestEndDate, title: "Request End")
        addDate(timing.responseStartDate, title: "Response Start")
        addDate(timing.responseEndDate, title: "Response End")
#if !os(watchOS)
        let longestTitleCount = items.map(\.0.count).max() ?? 0
        items = items.map {
            ($0.0.padding(toLength: longestTitleCount + 1, withPad: " ", startingAt: 0), $0.1)
        }
#endif
        return KeyValueSectionViewModel(title: "Timing", color: .orange, items: items)
    }

    private static func makeTransferSection(for metrics: NetworkTransactionMetricsEntity) -> KeyValueSectionViewModel? {
        let transferSize = metrics.transferSize
        return KeyValueSectionViewModel(title: "Data Transfer", color: .primary, items: [
            ("Request Headers", formatBytes(transferSize.requestHeaderBytesSent)),
            ("Request Body", formatBytes(transferSize.requestBodyBytesBeforeEncoding)),
            ("Request Body (Encoded)", formatBytes(transferSize.requestBodyBytesSent)),
            ("Response Headers", formatBytes(transferSize.responseHeaderBytesReceived)),
            ("Response Body", formatBytes(transferSize.responseBodyBytesReceived)),
            ("Response Body (Decoded)", formatBytes(transferSize.responseBodyBytesAfterDecoding))
        ])
    }

    private static func makeProtocolSection(for metrics: NetworkTransactionMetricsEntity) -> KeyValueSectionViewModel? {
        KeyValueSectionViewModel(title: "Protocol", color: .primary, items: [
            ("Network Protocol", metrics.networkProtocol),
            ("Remote Address", metrics.remoteAddress),
            ("Remote Port", metrics.remotePort > 0 ? String(metrics.remotePort) : nil),
            ("Local Address", metrics.localAddress),
            ("Local Port", metrics.localPort > 0 ? String(metrics.localPort) : nil)
        ])
    }

    private static func makeSecuritySection(for metrics: NetworkTransactionMetricsEntity) -> KeyValueSectionViewModel? {
        guard let suite = metrics.negotiatedTLSCipherSuite,
              let version = metrics.negotiatedTLSProtocolVersion else {
            return nil
        }
        return KeyValueSectionViewModel(title: "Security", color: .primary, items: [
            ("Cipher Suite", suite.description),
            ("Protocol Version", version.description)
        ])
    }

    private static func makeMiscSection(for metrics: NetworkTransactionMetricsEntity) -> KeyValueSectionViewModel? {
        KeyValueSectionViewModel(title: "Characteristics", color: .primary, items: [
            ("Cellular", metrics.isCellular.description),
            ("Expensive", metrics.isExpensive.description),
            ("Constrained", metrics.isConstrained.description),
            ("Proxy Connection", metrics.isProxyConnection.description),
            ("Reused Connection", metrics.isReusedConnection.description),
            ("Multipath", metrics.isMultipath.description)
        ])
    }

    static func makeDetails(for cookie: HTTPCookie, color: Color) -> KeyValueSectionViewModel {
        KeyValueSectionViewModel(title: cookie.name, color: color, items: [
            ("Name", cookie.name),
            ("Value", cookie.value),
            ("Domain", cookie.domain),
            ("Path", cookie.path),
            ("Expires", cookie.expiresDate?.description(with: Locale(identifier: "en_US"))),
            ("Secure", "\(cookie.isSecure)"),
            ("HTTP Only", "\(cookie.isHTTPOnly)"),
            ("Session Only", "\(cookie.isSessionOnly)")
        ])
    }
}

private func formatBytes(_ count: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: count)
}


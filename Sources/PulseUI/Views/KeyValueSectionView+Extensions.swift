// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

extension KeyValueSectionViewModel {
    static func makeSummary(for request: NetworkRequestEntity) -> KeyValueSectionViewModel {
        let components = request.url.flatMap { URLComponents(string: $0) }
        var items: [(String, String?)] = []
        items += [
            ("URL", request.url),
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

    static func makeParameters(for request: NetworkRequestEntity) -> KeyValueSectionViewModel {
        KeyValueSectionViewModel(title: "Request Parameters", color: .gray, items: [
            ("Cache Policy", request.cachePolicy.description),
            ("Timeout Interval", DurationFormatter.string(from: TimeInterval(request.timeoutInterval), isPrecise: false)),
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

    static func makeSummary(for response: NetworkResponseEntity) -> KeyValueSectionViewModel {
        KeyValueSectionViewModel(title: "Response Summary", color: .indigo, items: [
            ("Status Code", String(response.statusCode)),
            ("Content Type", response.contentType?.rawValue),
            ("Expected Content Length", response.expectedContentLength.map { ByteCountFormatter.string(fromByteCount: max(0, $0)) })
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

    static func makeErrorDetails(for task: NetworkTaskEntity, action: @escaping () -> Void) -> KeyValueSectionViewModel? {
        guard task.errorCode != 0, task.state == .failure else {
            return nil
        }
        return KeyValueSectionViewModel(
            title: "Error",
            color: .red,
            action: ActionViewModel(action: action, title: "View"),
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
        return "\(code) (\(descriptionForURLErrorCode(Int(code)))"
    }

    static func makeQueryItems(for url: URL, action: @escaping () -> Void) -> KeyValueSectionViewModel? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              !queryItems.isEmpty else {
            return nil
        }
        return makeQueryItems(for: queryItems, action: action)
    }

    static func makeQueryItems(for queryItems: [URLQueryItem], action: @escaping () -> Void) -> KeyValueSectionViewModel? {
        KeyValueSectionViewModel(
            title: "Query Items",
            color: .blue,
            action: ActionViewModel(action: action, title: "View"),
            items: queryItems.map { ($0.name, $0.value) }
        )
    }

#if os(iOS) || os(macOS)
    static func makeTiming(for transaction: NetworkTransactionMetricsEntity) -> KeyValueSectionViewModel {
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US")
        timeFormatter.dateFormat = "HH:mm:ss.SSSSSS"

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
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

        return KeyValueSectionViewModel(title: "Timing", color: .orange, items: items)
    }
#endif
}

extension KeyValueSectionViewModel {
    func asAttributedString() -> NSAttributedString {
        let output = NSMutableAttributedString()
        for item in items {
            var titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UXFont.monospacedSystemFont(ofSize: FontSize.body, weight: .semibold)
            ]
            if #available(iOS 14.0, tvOS 14.0, *) {
                titleAttributes[.foregroundColor] = UXColor(color)
            } else {
#if os(iOS) || os(macOS)
                titleAttributes[.foregroundColor] = UXColor.label
#endif
            }
            output.append(item.0, titleAttributes)

            var valueAttributes: [NSAttributedString.Key: Any] = [
                .font: UXFont.monospacedSystemFont(ofSize: FontSize.body, weight: .regular)
            ]
#if os(iOS) || os(macOS)
            valueAttributes[.foregroundColor] = UXColor.label
#endif
            output.append(": \(item.1 ?? "–")\n", valueAttributes)
        }
        output.addAttributes([.paragraphStyle:  NSParagraphStyle.make(lineHeight: FontSize.body + 5)])
        return output
    }
}

// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

// MARK: - View

#if os(iOS) || os(watchOS) || os(macOS)

struct NetworkInspectorSummaryView: View {
    @ObservedObject var viewModel: NetworkInspectorSummaryViewModel

    var body: some View {
        ScrollView {
            #if os(watchOS)
            Spacer().frame(height: 24)
            VStack(spacing: 24) {
                contents
            }
            #else
            VStack(spacing: 8) {
                contents
            }.padding()
            #endif
        }
    }

    @ViewBuilder
    private var contents: some View {
        #if !os(watchOS)
        if let transfer = viewModel.transferModel {
            Spacer().frame(height: 12)
            NetworkInspectorTransferInfoView(viewModel: transfer)
            Spacer().frame(height: 20)
        }
        #endif
        KeyValueSectionView(viewModel: viewModel.summaryModel)
        if let error = viewModel.errorModel {
            KeyValueSectionView(viewModel: error)
        }
        if let request = viewModel.requestBodySection {
            KeyValueSectionView(viewModel: request)
        }
        if let response = viewModel.responseBodySection {
            KeyValueSectionView(viewModel: response)
        }
        if let timing = viewModel.timingDetailsModel {
            KeyValueSectionView(viewModel: timing)
        }
        if let parameters = viewModel.parametersModel {
            KeyValueSectionView(viewModel: parameters)
        }

        #if os(watchOS)
        KeyValueSectionView(viewModel: viewModel.requestHeaders)
        if let responseHeaders = viewModel.responseHeaders {
            KeyValueSectionView(viewModel: responseHeaders)
        }
        #endif

        linksView

        #if !os(watchOS)
        Spacer()
        #endif
    }

    private var linksView: some View {
        VStack {
            if let errorModel = viewModel.errorModel {
                NavigationLink(destination: NetworkHeadersDetailsView(viewModel: errorModel), isActive: $viewModel.isErrorRawActive) {
                    Text("")
                }
            }

            NavigationLink(destination: NetworkInspectorResponseView(viewModel: viewModel.requestBodyViewModel), isActive: $viewModel.isRequestRawActive) {
                Text("")
            }

            NavigationLink(destination: NetworkInspectorResponseView(viewModel: viewModel.responseBodyViewModel), isActive: $viewModel.isResponseRawActive) {
                Text("")
            }

            #if os(watchOS)
            NavigationLink(destination: NetworkHeadersDetailsView(viewModel: viewModel.requestHeaders), isActive: $viewModel.isRequestHeadersRawActive) {
                Text("")
            }

            if let responesHeaders = viewModel.responseHeaders {
                NavigationLink(destination: NetworkHeadersDetailsView(viewModel: responesHeaders), isActive: $viewModel.isResponseHeadearsRawActive) {
                    Text("")
                }
            }
            #endif
        }
        .frame(height: 0)
        .hidden()

    }
}

#endif

// MARK: - ViewModel

final class NetworkInspectorSummaryViewModel: ObservableObject {
    private let summary: NetworkLoggerSummary

    @Published var isErrorRawActive = false
    @Published var isRequestRawActive = false
    @Published var isResponseRawActive = false

    #if os(watchOS) || os(tvOS)
    @Published var isRequestHeadersRawActive = false
    @Published var isRequestAdditionalHeadersRawActive = false
    @Published var isResponseHeadearsRawActive = false
    #endif

    init(summary: NetworkLoggerSummary) {
        self.summary = summary
    }

    private var tintColor: Color {
        switch summary.state {
        case .pending: return .orange
        case .success: return .green
        case .failure: return .red
        }
    }

    var summaryModel: KeyValueSectionViewModel {
        KeyValueSectionViewModel(
            title: "Summary",
            color: tintColor,
            items: [
                ("Status Code", summary.response?.statusCode.map(StatusCodeFormatter.string) ?? "–"),
                ("Method", summary.request?.httpMethod ?? "–"),
                ("URL", summary.request?.url?.absoluteString ?? "–"),
                ("Domain", summary.request?.url?.host ?? "–")
            ])
    }

    var errorModel: KeyValueSectionViewModel? {
        guard let error = summary.error else { return nil }
        return KeyValueSectionViewModel(
            title: "Error",
            color: .red,
            action: ActionViewModel(
                action: { [unowned self] in isErrorRawActive = true },
                title: "View"
            ),
            items: [
                ("Domain", error.domain),
                ("Code", descriptionForError(domain: error.domain, code: error.code)),
                ("Message", error.localizedDescription)
            ])
    }

    var requestBodySection: KeyValueSectionViewModel? {
        guard summary.requestBodyKey != nil, summary.requestBodySize > 0 else {
            return nil
        }
        let contentType = summary.request?.headers.first(where: { $0.key == "Content-Type" })?.value ?? "–"
        return KeyValueSectionViewModel(
            title: "Request Body",
            color: .blue,
            action: ActionViewModel(
                action: { [unowned self] in isRequestRawActive = true },
                title: "View"
            ),
            items: [
                ("Content-Type", contentType),
                ("Size", ByteCountFormatter.string(fromByteCount: summary.requestBodySize, countStyle: .file))
            ]
        )
    }

    var responseBodySection: KeyValueSectionViewModel? {
        guard summary.responseBodyKey != nil, summary.responseBodySize > 0 else {
            return nil
        }
        let contentType = summary.response?.headers.first(where: { $0.key == "Content-Type" })?.value ?? "–"
        let isFromCache = summary.metrics?.transactions.last?.resourceFetchType == URLSessionTaskMetrics.ResourceFetchType.localCache.rawValue
        let size = ByteCountFormatter.string(fromByteCount: summary.responseBodySize, countStyle: .file)
        return KeyValueSectionViewModel(
            title: "Response Body",
            color: .indigo,
            action: ActionViewModel(
                action: { [unowned self] in isResponseRawActive = true },
                title: "View"
            ),
            items: [
                ("Content-Type", contentType),
                ("Size", isFromCache ? size + " (from cache)": size)
            ]
        )
    }

    var requestBodyViewModel: NetworkInspectorResponseViewModel {
        let summary = self.summary
        return NetworkInspectorResponseViewModel(title: "Request", data: summary.requestBody ?? Data())
    }

    var responseBodyViewModel: NetworkInspectorResponseViewModel {
        let summary = self.summary
        return NetworkInspectorResponseViewModel(title: "Response", data: summary.responseBody ?? Data())
    }

    var transferModel: NetworkInspectorTransferInfoViewModel? {
        summary.metrics.flatMap(NetworkInspectorTransferInfoViewModel.init)
    }

    var timingDetailsModel: KeyValueSectionViewModel? {
        guard let metrics = summary.metrics else { return nil }
        return KeyValueSectionViewModel(title: "Timing", color: .gray, items: [
            ("Start Date", isoFormatter.string(from: metrics.taskInterval.start)),
            ("End Date", isoFormatter.string(from: metrics.taskInterval.end)),
            ("Duration", DurationFormatter.string(from: metrics.taskInterval.duration)),
            ("Redirect Count", metrics.redirectCount.description)
        ])
    }

    var parametersModel: KeyValueSectionViewModel? {
        guard let request = summary.request else { return nil }
        return KeyValueSectionViewModel(title: "Parameters", color: .gray, items: [
            ("Cache Policy", URLRequest.CachePolicy(rawValue: request.cachePolicy).map { $0.description }),
            ("Timeout Interval", DurationFormatter.string(from: request.timeoutInterval)),
            ("Allows Cellular Access", request.allowsCellularAccess.description),
            ("Allows Expensive Network Access", request.allowsExpensiveNetworkAccess.description),
            ("Allows Constrained Network Access", request.allowsConstrainedNetworkAccess.description),
            ("HTTP Should Handle Cookies", request.httpShouldHandleCookies.description),
            ("HTTP Should Use Pipelining", request.httpShouldUsePipelining.description)
        ])
    }

    #if os(watchOS) || os(tvOS)
    var requestHeaders: KeyValueSectionViewModel {
        let items = (summary.request?.headers ?? [:]).sorted(by: { $0.key < $1.key })
        return KeyValueSectionViewModel(
            title: "Request Headers",
            color: .blue,
            action: ActionViewModel(
                action: { [unowned self] in isRequestHeadersRawActive = true },
                title: "View Raw"
            ),
            items: items
        )
    }

    var responseHeaders: KeyValueSectionViewModel? {
        guard let headers = summary.response?.headers else {
            return nil
        }
        return KeyValueSectionViewModel(
            title: "Response Headers",
            color: .indigo,
            action: ActionViewModel(
                action: { [unowned self] in isResponseHeadearsRawActive = true },
                title: "View Raw"
            ),
            items: headers.sorted(by: { $0.key < $1.key })
        )
    }
    #endif
}

// MARK: - Private

private let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

private func descriptionForError(domain: String, code: Int) -> String {
    guard domain == NSURLErrorDomain else {
        return "\(code)"
    }
    return "\(code) (\(descriptionForURLErrorCode(code)))"
}

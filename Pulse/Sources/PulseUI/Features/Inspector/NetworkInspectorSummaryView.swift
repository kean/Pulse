// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

// MARK: - View

#if os(iOS) || os(watchOS) || os(macOS)

@available(iOS 13.0, watchOS 6, *)
struct NetworkInspectorSummaryView: View {
    @ObservedObject var model: NetworkInspectorSummaryViewModel

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
        if let transfer = model.transferModel {
            Spacer().frame(height: 12)
            NetworkInspectorTransferInfoView(model: transfer)
            Spacer().frame(height: 20)
        }
        #endif
        KeyValueSectionView(model: model.summaryModel)
        if let error = model.errorModel {
            KeyValueSectionView(model: error)
        }
        if let request = model.requestBodySection {
            KeyValueSectionView(model: request)
        }
        if let response = model.responseBodySection {
            KeyValueSectionView(model: response)
        }
        if let timing = model.timingDetailsModel {
            KeyValueSectionView(model: timing)
        }
        if let parameters = model.parametersModel {
            KeyValueSectionView(model: parameters)
        }

        #if os(watchOS)
        KeyValueSectionView(model: model.requestHeaders)
        if let additional = model.httpAdditionalHeaders {
            KeyValueSectionView(model: additional)
        }
        KeyValueSectionView(model: model.responseHeaders)
        #endif

        linksView

        #if !os(watchOS)
        Spacer()
        #endif
    }

    private var linksView: some View {
        VStack {
            if let errorModel = model.errorModel {
                NavigationLink(destination: NetworkHeadersDetailsView(model: errorModel), isActive: $model.isErrorRawActive) {
                    Text("")
                }
            }
            
            NavigationLink(destination: NetworkInspectorResponseView(model: model.requestBodyViewModel), isActive: $model.isRequestRawActive) {
                Text("")
            }

            NavigationLink(destination: NetworkInspectorResponseView(model: model.responseBodyViewModel), isActive: $model.isResponseRawActive) {
                Text("")
            }

            #if os(watchOS)
            NavigationLink(destination: NetworkHeadersDetailsView(model: model.requestHeaders), isActive: $model.isRequestHeadersRawActive) {
                Text("")
            }

            if let additional = model.httpAdditionalHeaders {
                NavigationLink(destination: NetworkHeadersDetailsView(model: additional), isActive: $model.isRequestAdditionalHeadersRawActive) {
                    Text("")
                }.hidden()
            }
            
            NavigationLink(destination: NetworkHeadersDetailsView(model: model.responseHeaders), isActive: $model.isResponseHeadearsRawActive) {
                Text("")
            }
            #endif
        }
        .frame(height: 0)
        .hidden()

    }
}

#endif

// MARK: - ViewModel

@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
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

    private var isSuccess: Bool {
        guard let response = summary.response else {
            return false
        }
        return summary.error == nil && (200..<400).contains(response.statusCode ?? 200)
    }

    private var tintColor: Color {
        guard summary.response != nil else {
            return .gray
        }
        return isSuccess ? .green : .red
    }

    lazy var summaryModel: KeyValueSectionViewModel = {
        KeyValueSectionViewModel(
            title: "Summary",
            color: tintColor,
            items: [
                ("URL", "https://www.google.ru/search?q=very+long+google+url&newwindow=1&hl=en&source=hp&ei=r_RqYfnxB7X59AP8z6Qg&iflsig=ALs-wAMAAAAAYWsCv804bF6Tig_Q0HLznCCxGCmznP-v&ved=0ahUKEwi5hdWgpM_zAhW1PH0KHfwnCQQQ4dUDCAw&uact=5&oq=very+long+google+url&gs_lcp=Cgdnd3Mtd2l6EAMyBQghEKABMgUIIRCgAToRCC4QgAQQsQMQxwEQowIQkwI6DgguEIAEELEDEMcBENEDOgUIABCABDoLCC4QgAQQxwEQowI6CAgAELEDEIMBOgsILhCABBDHARCvAToOCC4QgAQQsQMQxwEQowI6CAguELEDEIMBOggIABCABBCxAzoRCC4QgAQQsQMQgwEQxwEQrwE6CAguEIAEELEDOgsIABCABBCxAxDJAzoFCAAQkgM6BwguELEDEAo6DQguELEDEMcBENEDEAo6CgguEMcBEK8BEAo6BAguEAo6BAgAEAo6DQguELEDEMcBEKMCEAo6EAguEIAEEMcBEKMCEAoQkwI6BwgAEIAEEAo6CwguELEDEMcBEKMCOgsILhCABBCxAxCDAToLCC4QgAQQxwEQ0QM6CAgAEIAEEMkDOhEILhCABBCxAxCDARDHARDRAzoLCAAQgAQQsQMQgwE6CwguEIAEELEDEJMCOg4ILhCABBCxAxDHARCvAToGCAAQFhAeOggIABAWEAoQHjoFCAAQhgM6BQghEKsCOgcIIRAKEKABUMkGWNAgYKAhaABwAHgAgAGLAYgB9g-SAQQyMC41mAEAoAEB&sclient=gws-wiz"),
                ("Method", summary.request?.httpMethod ?? "–"),
                ("Status Code", summary.response?.statusCode.map(StatusCodeFormatter.string) ?? "–")
            ])
    }()

    lazy var errorModel: KeyValueSectionViewModel? = {
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
    }()

    lazy var requestBodySection: KeyValueSectionViewModel? = {
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
    }()

    lazy var responseBodySection: KeyValueSectionViewModel? = {
        guard summary.responseBodyKey != nil, summary.responseBodySize > 0 else {
            return nil
        }
        let contentType = summary.response?.headers.first(where: { $0.key == "Content-Type" })?.value ?? "–"
        return KeyValueSectionViewModel(
            title: "Response Body",
            color: .indigo,
            action: ActionViewModel(
                action: { [unowned self] in isResponseRawActive = true },
                title: "View"
            ),
            items: [
                ("Content-Type", contentType),
                ("Size", ByteCountFormatter.string(fromByteCount: summary.responseBodySize, countStyle: .file))
            ]
        )
    }()

    lazy var requestBodyViewModel: NetworkInspectorResponseViewModel = {
        let summary = self.summary
        return NetworkInspectorResponseViewModel(title: "Request", data: summary.requestBody ?? Data())
    }()

    lazy var responseBodyViewModel: NetworkInspectorResponseViewModel = {
        let summary = self.summary
        return NetworkInspectorResponseViewModel(title: "Response", data: summary.responseBody ?? Data())
    }()

    lazy var transferModel: NetworkInspectorTransferInfoViewModel? = {
        summary.metrics.flatMap(NetworkInspectorTransferInfoViewModel.init)
    }()

    lazy var timingDetailsModel: KeyValueSectionViewModel? = {
        guard let metrics = summary.metrics else { return nil }
        return KeyValueSectionViewModel(title: "Timing", color: .gray, items: [
            ("Start Date", dateFormatter.string(from: metrics.taskInterval.start)),
            ("Duration", DurationFormatter.string(from: metrics.taskInterval.duration)),
            ("Redirect Count", metrics.redirectCount.description),
        ])
    }()

    lazy var parametersModel: KeyValueSectionViewModel? = {
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
    }()

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
    
    var httpAdditionalHeaders: KeyValueSectionViewModel? {
        guard let headers = summary.session?.httpAdditionalHeaders else {
            return nil
        }
        let items = headers.sorted(by: { $0.key < $1.key })
        return KeyValueSectionViewModel(
            title: "Request Headers (Additional)",
            color: .blue,
            action: ActionViewModel(
                action: { [unowned self] in isRequestAdditionalHeadersRawActive = true },
                title: "View Raw"
            ),
            items: items
        )
    }

    var responseHeaders: KeyValueSectionViewModel {
        let items = (summary.response?.headers ?? [:]).sorted(by: { $0.key < $1.key })
        return KeyValueSectionViewModel(
            title: "Response Headers",
            color: .indigo,
            action: ActionViewModel(
                action: { [unowned self] in isResponseHeadearsRawActive = true },
                title: "View Raw"
            ),
            items: items
        )
    }
    #endif
}

// MARK: - Private

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.doesRelativeDateFormatting = true
    formatter.timeStyle = .medium
    return formatter
}()

private func descriptionForError(domain: String, code: Int) -> String {
    guard domain == NSURLErrorDomain else {
        return "\(code)"
    }
    return "\(code) (\(descriptionForURLErrorCode(code)))"
}

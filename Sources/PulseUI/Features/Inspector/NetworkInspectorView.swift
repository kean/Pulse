// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

// MARK: - View

#if os(iOS) || os(tvOS) || os(watchOS)
@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
struct NetworkInspectorView: View {
    // Make sure all tabs are updated live
    @ObservedObject var model: NetworkInspectorViewModel
    @State private var selectedTab: NetworkInspectorTab = .summary
    @State private var isShowingShareSheet = false
    @State private var shareItems: ShareItems?
    @Environment(\.colorScheme) private var colorScheme

    #if os(iOS)
    var body: some View {
        universalBody
            .navigationBarTitle(Text(model.title), displayMode: .inline)
            .navigationBarItems(trailing: HStack(spacing: 22) {
                PinButton(model: model.pin, isTextNeeded: false)
                if #available(iOS 14.0, *) {
                    Menu(content: {
                        NetworkMessageContextMenu(message: model.message, request: model.request, context: model.context, sharedItems: $shareItems)
                    }, label: {
                        Image(systemName: "square.and.arrow.up")
                    })
                } else {
                    ShareButton {
                        isShowingShareSheet = true
                    }
                }
            })
            .sheet(isPresented: $isShowingShareSheet) {
                ShareView(activityItems: [model.prepareForSharing()])
            }
            .sheet(item: $shareItems, content: ShareView.init)
    }
    #elseif os(watchOS)
    var body: some View {
        NetworkInspectorSummaryView(model: model.makeSummaryModel())
            .navigationBarTitle(Text(model.title))
            .toolbar {
                PinButton(model: model.pin, isTextNeeded: false)
            }
    }
    #elseif os(tvOS)
    var body: some View {
        List {
            let model = self.model.makeSummaryModel()

            makeKeyValueSection(model: model.summaryModel)

            if let error = model.errorModel {
                makeKeyValueSection(model: error)
            }
            if let request = model.requestBodySection {
                NavigationLink(destination: NetworkInspectorResponseView(model: model.requestBodyViewModel).focusable(true)) {
                    KeyValueSectionView(model: request)
                }
            }
            if let response = model.responseBodySection {
                NavigationLink(destination: NetworkInspectorResponseView(model: model.responseBodyViewModel).focusable(true)) {
                    KeyValueSectionView(model: response)
                }
            }
            if let timing = model.timingDetailsModel, let metrics = self.model.makeMetricsModel() {
                NavigationLink(destination: NetworkInspectorMetricsView(model: metrics).focusable(true)) {
                    KeyValueSectionView(model: timing)
                }
            }
            if let parameters = model.parametersModel {
                makeKeyValueSection(model: parameters)
            }

            makeKeyValueSection(model: model.requestHeaders)
            makeKeyValueSection(model: model.responseHeaders)
        }
    }

    func makeKeyValueSection(model: KeyValueSectionViewModel) -> some View {
        NavigationLink(destination: KeyValueSectionView(model: model).focusable(true)) {
            KeyValueSectionView(model: model, limit: 5)
        }
    }
    #else
    var body: some View {
        selectedTabView
            .background(colorScheme == .light ? Color(UXColor.controlBackgroundColor) : Color.clear)
            .toolbar(content: {
                Picker("", selection: $selectedTab) {
                    Text("Summary").tag(NetworkInspectorTab.summary)
                    Text("Headers").tag(NetworkInspectorTab.headers)
                    Text("Request").tag(NetworkInspectorTab.request)
                    Text("Response").tag(NetworkInspectorTab.response)
                    Text("Metrics").tag(NetworkInspectorTab.metrics)
                }
                .pickerStyle(SegmentedPickerStyle())
                Spacer()
                Menu(content: {
                    ShareMenuContent(model: .url, items: [model.prepareForSharing()])
                    NetworkMessageContextMenuCopySection(request: model.request, shareService: model.shareService)
                }, label: {
                    Image(systemName: "square.and.arrow.up")
                })
                PinButton(model: model.pin, isTextNeeded: false)
            })
    }
    #endif

    #if !os(watchOS) && !os(tvOS)
    private var universalBody: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Summary").tag(NetworkInspectorTab.summary)
                Text("Headers").tag(NetworkInspectorTab.headers)
                Text("Metrics").tag(NetworkInspectorTab.metrics)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(13)
            .border(width: 1, edges: [.bottom], color: Color(UXColor.separator).opacity(0.3))

            selectedTabView
        }
    }

    @ViewBuilder
    private var selectedTabView: some View {
        switch selectedTab {
        case .summary:
            NetworkInspectorSummaryView(model: model.makeSummaryModel())
        case .headers:
            NetworkInspectorHeadersView(model: model.makeHeadersModel())
        case .request:
            if let model = model.makeRequestBodyViewModel() {
                NetworkInspectorResponseView(model: model)
            } else {
                makePlaceholder
            }
        case .response:
            if let model = model.makeResponseBodyViewModel() {
                NetworkInspectorResponseView(model: model)
            } else {
                makePlaceholder
            }
        case .metrics:
            if let model = model.makeMetricsModel() {
                NetworkInspectorMetricsView(model: model)
            } else {
                makePlaceholder
            }
        }
    }
    #endif

    @ViewBuilder
    private var makePlaceholder: some View {
        PlaceholderView(imageName: "exclamationmark.circle", title: "Not Available")
    }
}

private enum NetworkInspectorTab: Identifiable {
    case summary
    case headers
    case request
    case response
    case metrics

    var id: NetworkInspectorTab { self }

    var text: String {
        switch self {
        case .summary: return "Summary"
        case .headers: return "Headers"
        case .request: return "Request"
        case .response: return "Response"
        case .metrics: return "Metrics"
        }
    }
}

// MARK: - ViewModel

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
final class NetworkInspectorViewModel: ObservableObject {
    private(set) var title: String = ""
    let message: LoggerMessageEntity
    let request: LoggerNetworkRequestEntity
    private let objectId: NSManagedObjectID
    let context: AppContext // TODO: make it private
    private let summary: NetworkLoggerSummary

    init(message: LoggerMessageEntity, request: LoggerNetworkRequestEntity, context: AppContext) {
        self.objectId = message.objectID
        self.message = message
        self.request = request
        self.context = context
        self.summary = NetworkLoggerSummary(request: request, store: context.store)

        if let url = request.url.flatMap(URL.init(string:)) {
            if let httpMethod = request.httpMethod {
                self.title = "\(httpMethod) /\(url.lastPathComponent)"
            } else {
                self.title = "/" + url.lastPathComponent
            }
        }
    }

    var pin: PinButtonViewModel {
        PinButtonViewModel(store: context.store, message: message)
    }

    // MARK: - Tabs

    func makeSummaryModel() -> NetworkInspectorSummaryViewModel {
        NetworkInspectorSummaryViewModel(summary: summary)
    }

    func makeHeadersModel() -> NetworkInspectorHeaderViewModel {
        NetworkInspectorHeaderViewModel(summary: summary)
    }

    func makeRequestBodyViewModel() -> NetworkInspectorResponseViewModel? {
        guard let requestBody = summary.requestBody, !requestBody.isEmpty else { return nil }
        return NetworkInspectorResponseViewModel(title: "Request", data: requestBody)
    }

    func makeResponseBodyViewModel() -> NetworkInspectorResponseViewModel? {
        guard let responseBody = summary.responseBody, !responseBody.isEmpty else { return nil }
        return NetworkInspectorResponseViewModel(title: "Response", data: responseBody)
    }

    #if !os(watchOS)
    func makeMetricsModel() -> NetworkInspectorMetricsViewModel? {
        summary.metrics.map(NetworkInspectorMetricsViewModel.init)
    }
    #endif

    // MARK: Sharing

    func prepareForSharing() -> String {
        ConsoleShareService(store: context.store).share(summary, output: .plainText)
    }

    var shareService: ConsoleShareService {
        ConsoleShareService(store: context.store)
    }
}
#endif

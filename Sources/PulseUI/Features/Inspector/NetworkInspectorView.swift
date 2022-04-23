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
    @ObservedObject var viewModel: NetworkInspectorViewModel
    @State private var selectedTab: NetworkInspectorTab = .summary
    @State private var isShowingShareSheet = false
    @State private var shareItems: ShareItems?
    @Environment(\.colorScheme) private var colorScheme

    #if os(iOS)
    var body: some View {
        universalBody
            .navigationBarTitle(Text(viewModel.title), displayMode: .inline)
            .navigationBarItems(trailing: HStack(spacing: 22) {
                if let pin = viewModel.pin {
                    PinButton(viewModel: pin, isTextNeeded: false)
                }
                if #available(iOS 14.0, *) {
                    Menu(content: {
                        NetworkMessageContextMenu(request: viewModel.request, store: viewModel.store, sharedItems: $shareItems)
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
                ShareView(activityItems: [viewModel.prepareForSharing()])
            }
            .sheet(item: $shareItems, content: ShareView.init)
    }
    #elseif os(watchOS)
    var body: some View {
        NetworkInspectorSummaryView(viewModel: viewModel.makeSummaryModel())
            .navigationBarTitle(Text(viewModel.title))
            .toolbar {
                if let viewModel = viewModel.pin {
                    PinButton(viewModel: viewModel, isTextNeeded: false)
                }
            }
    }
    #elseif os(tvOS)
    var body: some View {
        List {
            let viewModel = self.viewModel.makeSummaryModel()

            makeKeyValueSection(viewModel: viewModel.summaryModel)

            if let error = viewModel.errorModel {
                makeKeyValueSection(viewModel: error)
            }
            if let request = viewModel.requestBodySection {
                NavigationLink(destination: NetworkInspectorResponseView(viewModel: viewModel.requestBodyViewModel).focusable(true)) {
                    KeyValueSectionView(viewModel: request)
                }
            }
            if let response = viewModel.responseBodySection {
                NavigationLink(destination: NetworkInspectorResponseView(viewModel: viewModel.responseBodyViewModel).focusable(true)) {
                    KeyValueSectionView(viewModel: response)
                }
            }
            if let timing = viewModel.timingDetailsModel, let metrics = self.viewModel.makeMetricsModel() {
                NavigationLink(destination: NetworkInspectorMetricsView(viewModel: metrics).focusable(true)) {
                    KeyValueSectionView(viewModel: timing)
                }
            }
            if let parameters = viewModel.parametersModel {
                makeKeyValueSection(viewModel: parameters)
            }

            makeKeyValueSection(viewModel: viewModel.requestHeaders)
            makeKeyValueSection(viewModel: viewModel.responseHeaders)
        }
    }

    func makeKeyValueSection(viewModel: KeyValueSectionViewModel) -> some View {
        NavigationLink(destination: KeyValueSectionView(viewModel: viewModel).focusable(true)) {
            KeyValueSectionView(viewModel: viewModel, limit: 5)
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
                PinButton(viewModel: model.pin, isTextNeeded: false)
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
            NetworkInspectorSummaryView(viewModel: viewModel.makeSummaryModel())
        case .headers:
            NetworkInspectorHeadersView(viewModel: viewModel.makeHeadersModel())
        case .request:
            if let model = viewModel.makeRequestBodyViewModel() {
                NetworkInspectorResponseView(viewModel: model)
            } else {
                makePlaceholder
            }
        case .response:
            if let model = viewModel.makeResponseBodyViewModel() {
                NetworkInspectorResponseView(viewModel: model)
            } else {
                makePlaceholder
            }
        case .metrics:
            if let model = viewModel.makeMetricsModel() {
                NetworkInspectorMetricsView(viewModel: model)
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
    let request: LoggerNetworkRequestEntity
    private let objectId: NSManagedObjectID
    let store: LoggerStore // TODO: make it private
    private let summary: NetworkLoggerSummary

    init(request: LoggerNetworkRequestEntity, store: LoggerStore) {
        self.objectId = request.objectID
        self.request = request
        self.store = store
        self.summary = NetworkLoggerSummary(request: request, store: store)

        if let url = request.url.flatMap(URL.init(string:)) {
            if let httpMethod = request.httpMethod {
                self.title = "\(httpMethod) /\(url.lastPathComponent)"
            } else {
                self.title = "/" + url.lastPathComponent
            }
        }
    }

    var pin: PinButtonViewModel? {
        request.message.map {
            PinButtonViewModel(store: store, message: $0)
        }
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
        ConsoleShareService(store: store).share(summary, output: .plainText)
    }

    var shareService: ConsoleShareService {
        ConsoleShareService(store: store)
    }
}
#endif

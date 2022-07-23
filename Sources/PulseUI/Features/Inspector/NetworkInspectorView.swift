// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

struct NetworkInspectorView: View {
    // Make sure all tabs are updated live
    @ObservedObject var viewModel: NetworkInspectorViewModel
    @State private var selectedTab: NetworkInspectorTab = .response
    @State private var isShowingShareSheet = false
    @State private var shareItems: ShareItems?
    @Environment(\.colorScheme) private var colorScheme

#if os(iOS)
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            selectedTabView
        }
        .navigationBarTitle(Text(viewModel.title), displayMode: .inline)
        .navigationBarItems(trailing: trailingNavigationBarItems)
        .sheet(isPresented: $isShowingShareSheet) {
            ShareView(activityItems: [viewModel.prepareForSharing()])
        }
        .sheet(item: $shareItems, content: ShareView.init)
    }

    private var toolbar: some View {
        Picker("", selection: $selectedTab) {
            Text("Response").tag(NetworkInspectorTab.response)
            Text("Request").tag(NetworkInspectorTab.request)
            Text("Summary").tag(NetworkInspectorTab.summary)
            Text("Metrics").tag(NetworkInspectorTab.metrics)
        }
        .pickerStyle(.segmented)
        .padding(EdgeInsets(top: 6, leading: 13, bottom: 11, trailing: 13))
        .border(width: 1, edges: [.bottom], color: Color(UXColor.separator).opacity(0.3))
    }

    @ViewBuilder
    private var trailingNavigationBarItems: some View {
        if #available(iOS 14.0, *) {
            Menu(content: {
                NetworkMessageContextMenu(request: viewModel.request, store: viewModel.store, sharedItems: $shareItems)
            }, label: {
                Image(systemName: "ellipsis.circle")
            })
        } else {
            ShareButton {
                isShowingShareSheet = true
            }
        }
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
            if let parameters = viewModel.requestParameters {
                makeKeyValueSection(viewModel: parameters)
            }

            makeKeyValueSection(viewModel: viewModel.requestHeaders)
            if let responseHeaders = viewModel.responseHeaders {
                makeKeyValueSection(viewModel: responseHeaders)
            }
        }
    }

    func makeKeyValueSection(viewModel: KeyValueSectionViewModel) -> some View {
        NavigationLink(destination: KeyValueSectionView(viewModel: viewModel).focusable(true)) {
            KeyValueSectionView(viewModel: viewModel, limit: 5)
        }
    }
#elseif os(macOS)
    let onClose: () -> Void

    var body: some View {
        VStack {
            toolbar
            selectedTabView
        }
        .background(colorScheme == .light ? Color(UXColor.controlBackgroundColor) : Color.clear)
    }

    private var toolbar: some View {
        VStack(spacing: 0) {
            HStack {
                NetworkTabView(selectedTab: $selectedTab)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark").foregroundColor(.secondary)
                }.buttonStyle(PlainButtonStyle())
            }
            .padding(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 10))
            Divider()
        }
    }

    private struct NetworkTabView: View {
        @Binding var selectedTab: NetworkInspectorTab

        var body: some View {
            HStack(spacing: 0) {
                HStack {
                    makeItem("Response", tab: .response)
                    Divider()
                    makeItem("Request", tab: .request)
                    Divider()
                    makeItem("Headers", tab: .headers)
                    Divider()
                }
                HStack {
                    Spacer().frame(width: 8)
                    makeItem("Summary", tab: .summary)
                    Divider()
                    makeItem("Metrics", tab: .metrics)
                }
            }.fixedSize()
        }

        private func makeItem(_ title: String, tab: NetworkInspectorTab) -> some View {
            Button(action: {
                selectedTab = tab
            }) {
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundColor(tab == selectedTab ? .accentColor : .primary)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

#endif

#if os(iOS) || os(macOS)

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
            } else if !viewModel.isCompleted && !viewModel.store.isReadonly {
                pending
            } else if viewModel.hasRequestBody {
                PlaceholderView(imageName: "exclamationmark.circle", title: "Unavailable")
            } else {
                PlaceholderView(imageName: "nosign", title: "Empty Request")
            }
        case .response:
            if let model = viewModel.makeResponseBodyViewModel() {
                NetworkInspectorResponseView(viewModel: model)
            } else if !viewModel.isCompleted && !viewModel.store.isReadonly {
                pending
            } else if viewModel.hasResponseBody  {
                PlaceholderView(imageName: "exclamationmark.circle", title: "Unavailable")
            } else {
                PlaceholderView(imageName: "nosign", title: "Empty Response")
            }
        case .metrics:
            if let model = viewModel.makeMetricsModel() {
                NetworkInspectorMetricsView(viewModel: model)
            } else if !viewModel.isCompleted && !viewModel.store.isReadonly {
                pending
            } else {
                PlaceholderView(imageName: "exclamationmark.circle", title: "Unavailable")
            }
        }
    }
#endif

    @ViewBuilder
    private var pending: some View {
        VStack(spacing: 12) {
            Spinner()
            Text("Pending")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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

final class NetworkInspectorViewModel: ObservableObject {
    private(set) var title: String = ""
    let request: LoggerNetworkRequestEntity
    private let objectId: NSManagedObjectID
    let store: LoggerStore // TODO: make it private
    @Published private var summary: NetworkLoggerSummary
    private var cancellable: AnyCancellable?

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

        self.cancellable = request.objectWillChange.sink { [weak self] in
            self?.summary = NetworkLoggerSummary(request: request, store: store)
        }
    }

    var pin: PinButtonViewModel? {
        request.message.map {
            PinButtonViewModel(store: store, message: $0)
        }
    }

    var isCompleted: Bool {
        request.state == .failure || request.state == .success
    }

    var hasRequestBody: Bool {
        request.requestBodyKey != nil
    }

    var hasResponseBody: Bool {
        request.requestBodyKey != nil
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

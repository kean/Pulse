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
    var onClose: (() -> Void)?

    @State private var selectedTab: NetworkInspectorTab = .response
    @State private var isShowingShareSheet = false
    @State private var shareItems: ShareItems?
    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme

#if os(iOS)
    @State private var viewController: UIViewController?

    var body: some View {
        VStack(spacing: 0) {
            if !isExpanded {
                toolbar
            }
            selectedTabView
        }
        .navigationBarItems(trailing: trailingNavigationBarItems)
        .navigationBarHidden(isExpanded)
        .navigationBarTitle(Text(viewModel.title), displayMode: .inline)
        .statusBar(hidden: isExpanded)
        .sheet(isPresented: $isShowingShareSheet) {
            ShareView(activityItems: [viewModel.prepareForSharing()])
        }
        .sheet(item: $shareItems, content: ShareView.init)
        .background(ViewControllerAccessor(viewController: $viewController))
    }

    private var toolbar: some View {
        Picker("", selection: $selectedTab) {
            Text("Response").tag(NetworkInspectorTab.response)
            Text("Request").tag(NetworkInspectorTab.request)
            Text("Summary").tag(NetworkInspectorTab.summary)
            Text("Metrics").tag(NetworkInspectorTab.metrics)
        }
        .pickerStyle(.segmented)
        .padding(EdgeInsets(top: 4, leading: 13, bottom: 11, trailing: 13))
        .border(width: 1, edges: [.bottom], color: Color(UXColor.separator).opacity(0.3))
    }

    @ViewBuilder
    private var trailingNavigationBarItems: some View {
        HStack {
            if let pin = viewModel.pin {
                PinButton(viewModel: pin, isTextNeeded: false)
            }
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
    }
#elseif os(macOS)
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
                if let onClose = onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark").foregroundColor(.secondary)
                    }.buttonStyle(PlainButtonStyle())
                }
            }
            .padding(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 10))
            Divider()
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
        NetworkInspectorSummaryView(viewModel: viewModel.makeSummaryModel(), metrics: viewModel.makeMetricsModel())
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
                makeResponseView(viewModel: model)
            } else if !viewModel.isCompleted && !viewModel.store.isReadonly {
                pending
            } else if viewModel.hasRequestBody {
                PlaceholderView(imageName: "exclamationmark.circle", title: "Unavailable")
            } else {
                PlaceholderView(imageName: "nosign", title: "Empty Request")
            }
        case .response:
            if let model = viewModel.makeResponseBodyViewModel() {
                makeResponseView(viewModel: model)
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

    @ViewBuilder
    private func makeResponseView(viewModel: NetworkInspectorResponseViewModel) -> some View {
#if os(iOS)
        NetworkInspectorResponseView(viewModel: viewModel) {
            isExpanded.toggle()
            viewController?.navigationController?.setNavigationBarHidden(isExpanded, animated: false)
            viewController?.tabBarController?.setTabBarHidden(isExpanded, animated: false)
        }
#else
        NetworkInspectorResponseView(viewModel: viewModel)
#endif
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

#if os(macOS)
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
            self?.refresh()
        }
    }

    private func refresh() {
        _requestViewModel = nil
        _responseViewModel = nil
        summary = NetworkLoggerSummary(request: request, store: store)
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

    // important:
    private var _requestViewModel: NetworkInspectorResponseViewModel?

    func makeRequestBodyViewModel() -> NetworkInspectorResponseViewModel? {
        if let viewModel = _requestViewModel {
            return viewModel
        }
        guard let requestBody = summary.requestBody, !requestBody.isEmpty else { return nil }
        let viewModel = NetworkInspectorResponseViewModel(title: "Request", data: requestBody)
        _requestViewModel = viewModel
        return viewModel
    }

    // imporant:
    private var _responseViewModel: NetworkInspectorResponseViewModel?

    func makeResponseBodyViewModel() -> NetworkInspectorResponseViewModel? {
        if let viewModel = _responseViewModel {
            return viewModel
        }
        guard let responseBody = summary.responseBody, !responseBody.isEmpty else { return nil }
        let viewModel = NetworkInspectorResponseViewModel(title: "Response", data: responseBody)
        _responseViewModel = viewModel
        return viewModel
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

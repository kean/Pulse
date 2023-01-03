// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#warning("TODO: headers viewer better line height")

#warning("TODO: rework for other platfrms too")
#warning("TODO: rework trailing navigaiton bar buttons")
#warning("TODO: pass details to list items")
#warning("TODO: network details view to show fullscreen")
#warning("TODO: are destinations lazy?")

#warning("TODO: optimize task.responseCooki")
#warning("TODO: isShowingCurrentRequest remember persisetneyl")

#warning("TODO: show error (maybe simply in bottom seciont?")

#warning("TODO: handle all destinations")

#warning("TODO: move pin button to the bottom somewhere")

#warning("TODO: try variation with not tabbar at all!")

#warning("TODO: add context menu to URL and display query items")

#warning("TODO: try info icon for headers/cookies")



struct NetworkInspectorView: View {
#if os(watchOS)
    @StateObject var viewModel: NetworkInspectorViewModel
#else
    @ObservedObject var viewModel: NetworkInspectorViewModel
#endif
    var onClose: (() -> Void)?
    
#if os(macOS)
    @State private var selectedTab: NetworkInspectorTab = .response
#endif
    
#if os(iOS) || os(macOS)
    @State private var shareItems: ShareItems?
#endif
    
    @State private var isShowingCurrentRequest = false
    
#if os(iOS)
    var body: some View {
        contents
            .navigationBarItems(trailing: trailingNavigationBarItems)
            .navigationBarTitle(Text(viewModel.title), displayMode: .inline)
            .sheet(item: $shareItems, content: ShareView.init)
    }

    var contents: some View {
        Form {
            Section {
                transferStatusView
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)

            Section(footer: Text(viewModel.taskDetails)) {
                headerView
            }

            // TODO: display error
            
            Section(header: requestTypePickerView) {
                NavigationLink(destination: destinationRequestBody) {
                    MenuItem(
                        icon: "arrow.up.circle.fill",
                        tintColor: .blue,
                        title: "Request Body",
                        details: stringFromByteCount(viewModel.task.requestBodySize)
                    )
                }.disabled(viewModel.task.requestBodySize <= 0)
                if !isShowingCurrentRequest {
                    NavigationLink(destination: destinationOriginalRequestHeaders) {
                        MenuItem(
                            icon: "rectangle.tophalf.inset.filled",
                            tintColor: .secondary,
                            title: "Request Headers",
                            details: stringFromCount(viewModel.task.originalRequest?.headers.count)
                        )
                    }.disabled((viewModel.task.originalRequest?.headers.count ?? 0) == 0)
                    NavigationLink(destination: EmptyView()) {
                        MenuItem(
                            icon: "key.horizontal.fill",
                            tintColor: .secondary,
                            title: "Request Cookies",
                            details: stringFromCount(viewModel.task.originalRequest?.cookies.count)
                        )
                    }.disabled((viewModel.task.originalRequest?.cookies.count ?? 0) == 0)
                } else {
                    NavigationLink(destination: destinationCurrentRequestHeaders) {
                        MenuItem(
                            icon: "rectangle.tophalf.inset.filled",
                            tintColor: .secondary,
                            title: "Request Headers",
                            details: stringFromCount(viewModel.task.currentRequest?.headers.count)
                        )
                    }.disabled((viewModel.task.currentRequest?.headers.count ?? 0) == 0)
                    NavigationLink(destination: EmptyView()) {
                        MenuItem(
                            icon: "key.horizontal.fill",
                            tintColor: .secondary,
                            title: "Request Cookies",
                            details: stringFromCount(viewModel.task.currentRequest?.cookies.count)
                        )
                    }.disabled((viewModel.task.currentRequest?.cookies.count ?? 0) == 0)
                }
            }
            Section {
                NavigationLink(destination: destinationResponseBody) {
                    MenuItem(
                        icon: "arrow.down.circle.fill",
                        tintColor: .indigo,
                        title: "Response Body",
                        details: stringFromByteCount(viewModel.task.responseBodySize)
                    )
                }.disabled(viewModel.task.responseBodySize <= 0)
                NavigationLink(destination: EmptyView()) {
                    MenuItem(
                        icon: "rectangle.tophalf.inset.filled",
                        tintColor: .secondary,
                        title: "Response Headers",
                        details: stringFromCount(viewModel.task.response?.headers.count)
                    )
                }.disabled((viewModel.task.response?.headers.count ?? 0) == 0)
                NavigationLink(destination: EmptyView()) {
                    MenuItem(
                        icon: "key.horizontal.fill",
                        tintColor: .secondary,
                        title: "Response Cookies",
                        details: stringFromCount(viewModel.task.responseCookies.count)
                    )
                }.disabled(viewModel.task.responseCookies.count == 0)
            }
            Section {
                NavigationLink(destination: destinationMetrics) {
                    MenuItem(
                        icon: "clock.fill",
                        tintColor: .orange,
                        title: "Metrics",
                        details: stringFromCount(viewModel.task.transactions.count)
                    )
                }.disabled(!viewModel.task.hasMetrics)
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var transferStatusView: some View {
        if let transfer = viewModel.transferViewModel {
            NetworkInspectorTransferInfoView(viewModel: transfer)
        } else if let progress = viewModel.progressViewModel {
            ZStack {
                NetworkInspectorTransferInfoView(viewModel: .init(empty: true))
                    .hidden()
                    .backport.hideAccessibility()
                SpinnerView(viewModel: progress)
            }
        }
    }

    @ViewBuilder
    var headerView: some View {
        HStack(spacing: spacing) {
            Text(viewModel.task.httpMethod ?? "GET")
                .foregroundColor(viewModel.tintColor)
            Spacer()
            Text(viewModel.taskStatus)
                .foregroundColor(viewModel.tintColor)
            Image(systemName: viewModel.statusImageName)
                .foregroundColor(viewModel.tintColor)
        }.font(.headline)

        NavigationLink(destination: destinationURLView) {
            Text(viewModel.task.url ?? "–")
                .lineLimit(3)
                .font(.callout)
        }
    }

    @ViewBuilder
    private var requestTypePickerView: some View {
        HStack {
            Text("Request Type")
            Spacer()

            Picker("Request Type", selection: $isShowingCurrentRequest) {
                Text("Original").tag(false)
                Text("Current").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(.bottom, 3)
        }
    }
    
    // MARK: - Destinations

    @ViewBuilder
    private var destinationURLView: some View {
        if let url = viewModel.task.url.flatMap(URL.init) {
            NetworkDetailsView(title: "URL", text: KeyValueSectionViewModel.makeDetails(for: url))
        } else {
            Text("URL is Invalid")
                .foregroundColor(.secondary)
                .font(.headline)
        }
    }
    
    private var destinationOriginalRequestHeaders: some View {
        NetworkDetailsView(viewModel: viewModel.originalRequestHeadersViewModel.title("Request Headers"))
    }
    
    private var destinationCurrentRequestHeaders: some View {
        NetworkDetailsView(viewModel: viewModel.currenetRequestHeadersViewModel.title("Request Headers"))
    }
    
    private var destinationRequestCokies: some View {
        EmptyView()
    }
    
    private var destinationRequestBody: some View {
        NetworkInspectorRequestView(viewModel: NetworkInspectorRequestViewModel(task: viewModel.task))
    }
    
    private var destinationResponseBody: some View {
        NetworkInspectorResponseView(viewModel: NetworkInspectorResponseViewModel(task: viewModel.task))
    }
    
    private var destinationMetrics: some View {
        NetworkInspectorMetricsTabView(viewModel: NetworkInspectorMetricsTabViewModel(task: viewModel.task))
    }
    
    // MARK: - Helpers
    
    private struct MenuItem: View {
        let icon: String
        let tintColor: Color
        let title: String
        let details: String
        
        var body: some View {
            HStack {
                Image(systemName: icon)
                    .frame(width: 36)
                    .foregroundColor(tintColor)
                    .font(.system(size: 24))
                Text(title)
                Spacer()
                Text(details)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var trailingNavigationBarItems: some View {
        HStack {
            if let pin = viewModel.pin {
                PinButton(viewModel: pin, isTextNeeded: false)
            }
            if #available(iOS 14.0, *) {
                Menu(content: {
                    NetworkMessageContextMenu(task: viewModel.task, sharedItems: $shareItems)
                }, label: {
                    Image(systemName: "ellipsis.circle")
                })
            } else {
                ShareButton {
                    shareItems = ShareItems([viewModel.prepareForSharing()])
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
    }
    
    private var toolbar: some View {
        VStack(spacing: 0) {
            HStack {
                NetworkTabPickerView(selectedTab: $selectedTab)
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
#else
    var body: some View {
        NetworkInspectorSummaryView(viewModel: viewModel.summaryViewModel)
#if os(watchOS)
            .navigationBarTitle(Text(viewModel.title))
#endif
    }
#endif
    
#warning("TODO: move to -macOS")
    
#if os(macOS)
    @ViewBuilder
    private var selectedTabView: some View {
        switch selectedTab {
        case .response:
            NetworkInspectorResponseView(viewModel: viewModel.responseViewModel)
        case .request:
            NetworkInspectorRequestView(viewModel: viewModel.requestViewModel)
        case .summary:
            NetworkInspectorSummaryView(viewModel: viewModel.summaryViewModel)
        case .headers:
            NetworkInspectorHeadersTabView(viewModel: viewModel.headersViewModel)
        case .metrics:
            NetworkInspectorMetricsTabView(viewModel: viewModel.metricsViewModel)
        }
    }
#endif
}

#if os(macOS)
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

private struct NetworkTabPickerView: View {
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
        Button(action: { selectedTab = tab }) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .default))
                .foregroundColor(tab == selectedTab ? .accentColor : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
#endif

#if os(tvOS)
private let spacing: CGFloat = 20
#else
private let spacing: CGFloat? = nil
#endif

private func stringFromByteCount(_ count: Int64) -> String {
    guard count > 0 else {
        return "Empty"
    }
    return ByteCountFormatter.string(fromByteCount: count)
}

private func stringFromCount(_ count: Int?) -> String {
    guard let count = count, count > 0 else {
        return "Empty"
    }
    return count.description
}

#if DEBUG
struct NetworkInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NetworkInspectorView(viewModel: .init(task: LoggerStore.preview.entity(for: .login)))
        }
    }
}
#endif

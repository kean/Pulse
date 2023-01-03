// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#warning("TODO: fix size -1 bytes")
#warning("TODO: fix an issue with reload not working")
#warning("TODO: check if all deatils label are OK")

#warning("TODO: rework for other platfrms too")
#warning("TODO: rework trailing navigaiton bar buttons")
#warning("TODO: pass details to list items")
#warning("TODO: network details view to show fullscreen")
#warning("TODO: proper icons")
#warning("TODO: are destinations lazy?")
#warning("TODO: how to switch between current and original request? maube sections?")

#warning("TODO: optimize task.responseCooki")
#warning("TODO: isShowingCurrentRequest remember persisetneyl")

#warning("TODO: add query items")

#warning("TODO: show error (maybe simply in bottom seciont?")
#warning("TODO: resue preview")

#warning("TODO: handle all destinations")
#warning("TODO: improve how requst status is rendered")

#warning("TODO: fix hardcoded URLSessionDownloadTask")

#warning("TODO: move pin button to the bottom somewhere")

#warning("TODO: try variation with not tabbar at all!")

#warning("TODO: add context menu to URL and display query items")

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
    
    @ViewBuilder
    var contents: some View {
        Form {
            Section {
                headerView
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
            
            // TODO: pass action task and satus
            Section(footer: Text("URLSessionDownloadTask · 427ms · Network")) {
                HStack(spacing: spacing) {
                    
                    Text(viewModel.task.httpMethod ?? "GET")
                        .foregroundColor(viewModel.tintColor)
                    // TODO: pass status code
                    Spacer()
                    Text("200 OK")
                        .foregroundColor(viewModel.tintColor)
                    Image(systemName: viewModel.statusImageName)
                        .foregroundColor(viewModel.tintColor)
                }.font(.headline)
                
                // TODO: handle desctination
                // TODO: display query items there?
                NavigationLink(destination: EmptyView()) {
                    Text(viewModel.task.url ?? "–")
                        .lineLimit(3)
                        .font(.callout)
                }
            }
            
            Section(header: requestTypePickerView) {
                if !isShowingCurrentRequest {
                    NavigationLink(destination: destinationOriginalRequestHeaders) {
                        MenuItem(
                            icon: "info.square.fill",
                            tintColor: .blue,
                            title: "Request Headers",
                            details: String(viewModel.task.originalRequest?.headers.count ?? 0)
                        )
                    }.disabled((viewModel.task.originalRequest?.headers.count ?? 0) == 0)
                    NavigationLink(destination: EmptyView()) {
                        MenuItem(
                            icon: "arrow.down.square.fill",
                            tintColor: .blue,
                            title: "Request Cookies",
                            details: String(viewModel.task.originalRequest?.cookies.count ?? 0)
                        )
                    }.disabled((viewModel.task.originalRequest?.cookies.count ?? 0) == 0)
                } else {
                    NavigationLink(destination: destinationCurrentRequestHeaders) {
                        MenuItem(
                            icon: "info.square.fill",
                            tintColor: .blue,
                            title: "Request Headers",
                            details: String(viewModel.task.currentRequest?.headers.count ?? 0)
                        )
                    }.disabled((viewModel.task.currentRequest?.headers.count ?? 0) == 0)
                    NavigationLink(destination: EmptyView()) {
                        MenuItem(
                            icon: "arrow.down.square.fill",
                            tintColor: .blue,
                            title: "Request Cookies",
                            details: String(viewModel.task.currentRequest?.cookies.count ?? 0)
                        )
                    }.disabled((viewModel.task.currentRequest?.cookies.count ?? 0) == 0)
                }
                NavigationLink(destination: destinationRequestBody) {
                    MenuItem(
                        icon: "arrow.up.square.fill",
                        tintColor: .blue,
                        title: "Request Body",
                        details: ByteCountFormatter.string(fromByteCount: viewModel.task.requestBodySize)
                    )
                }.disabled(viewModel.task.requestBodySize == 0)
            }
            Section {
                NavigationLink(destination: destinationResponseBody) {
                    MenuItem(
                        icon: "arrow.down.square.fill",
                        tintColor: .indigo,
                        title: "Response Body",
                        details: ByteCountFormatter.string(fromByteCount: viewModel.task.responseBodySize)
                    )
                }.disabled(viewModel.task.responseBodySize == 0)
                NavigationLink(destination: EmptyView()) {
                    MenuItem(
                        icon: "arrow.down.square.fill",
                        tintColor: .indigo,
                        title: "Response Headers",
                        details: String(viewModel.task.response?.headers.count ?? 0)
                    )
                }.disabled((viewModel.task.response?.headers.count ?? 0) == 0)
                NavigationLink(destination: EmptyView()) {
                    MenuItem(
                        icon: "arrow.down.square.fill",
                        tintColor: .indigo,
                        title: "Response Cookies",
                        details: String(viewModel.task.responseCookies.count)
                    )
                }.disabled(viewModel.task.responseCookies.count == 0)
            }
            Section {
                NavigationLink(destination: destinationMetrics) {
                    MenuItem(
                        icon: "chart.bar.doc.horizontal.fill",
                        tintColor: .orange,
                        title: "Metrics",
                        details: String(viewModel.task.transactions.count)
                    )
                }.disabled(!viewModel.task.hasMetrics)
            }
        }
    }
    
    // MARK: - Subviews
    
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
    
    @ViewBuilder
    private var headerView: some View {
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
    
    // MARK: - Destinations
    
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
                    .foregroundColor(tintColor)
                    .font(.headline)
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

#if DEBUG
struct NetworkInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NetworkInspectorView(viewModel: .init(task: LoggerStore.preview.entity(for: .login)))
        }
    }
}
#endif

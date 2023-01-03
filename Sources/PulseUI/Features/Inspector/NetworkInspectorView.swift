// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#warning("TODO: pass details to list items")
#warning("TODO: network details view to show fullscreen")

#warning("TODO: optimize task.responseCookies")
#warning("TODO: isShowingCurrentRequest remember persisetneyl")

#warning("TODO: show error (maybe simply in bottom seciont?")

#warning("TODO: handle all destinations")

#warning("TODO: move pin button to the bottom somewhere")

#warning("TODO: try variation with not tabbar at all!")

#warning("TODO: add context menu to URL and display query items")


#warning("TODO: JWT where?")
#warning("TODO: rework for other platfrms too")

#warning("TODO: context actions for each cell")

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

            Section {
                headerView
            }
            Section(header: requestTypePickerView) {
                sectionRequest
            }
            if viewModel.task.state != .pending {
                Section {
                    sectionResponse
                }
                Section {
                    sectionMetrics
                }
            }
        }
    }

    @ViewBuilder
    private var sectionRequest: some View {
        NavigationLink(destination: destinationRequestBody) {
            MenuItem(
                icon: "arrow.up.circle",
                tintColor: .blue,
                title: "Request Body",
                details: stringFromByteCount(viewModel.task.requestBodySize)
            )
        }.disabled(viewModel.task.requestBodySize <= 0)
        if !isShowingCurrentRequest {
            NavigationLink(destination: destinationOriginalRequestHeaders) {
                MenuItem(
                    icon: "doc.plaintext",
                    tintColor: .secondary,
                    title: "Request Headers",
                    details: stringFromCount(viewModel.originalRequestHeaders.count)
                )
            }.disabled(viewModel.originalRequestHeaders.isEmpty)
            NavigationLink(destination: destinationOriginalRequestCookies) {
                MenuItem(
                    icon: "lock",
                    tintColor: .secondary,
                    title: "Request Cookies",
                    details: stringFromCount(viewModel.originalRequestCookies.count)
                )
            }.disabled(viewModel.originalRequestCookies.isEmpty)
        } else {
            NavigationLink(destination: destinationCurrentRequestHeaders) {
                MenuItem(
                    icon: "doc.plaintext",
                    tintColor: .secondary,
                    title: "Request Headers",
                    details: stringFromCount(viewModel.currentRequestHeaders.count)
                )
            }.disabled(viewModel.currentRequestHeaders.isEmpty)
            NavigationLink(destination: destinationCurrentRequestCookies) {
                MenuItem(
                    icon: "lock",
                    tintColor: .secondary,
                    title: "Request Cookies",
                    details: stringFromCount(viewModel.currentRequestCookies.count)
                )
            }.disabled(viewModel.currentRequestCookies.isEmpty)
        }
    }

    @ViewBuilder
    private var sectionResponse: some View {
        NavigationLink(destination: destinationResponseBody) {
            MenuItem(
                icon: "arrow.down.circle",
                tintColor: .indigo,
                title: "Response Body",
                details: {
                    if viewModel.task.responseBodySize > 0 {
                        var title = stringFromByteCount(viewModel.task.responseBodySize)
                        if viewModel.task.isFromCache {
                            title += " (Cache)"
                        }
                        return title
                    } else {
                        return "Empty"
                    }
                }()
            )
        }.disabled(viewModel.task.responseBodySize <= 0)
        NavigationLink(destination: destinationResponseHeaders) {
            MenuItem(
                icon: "doc.plaintext",
                tintColor: .secondary,
                title: "Response Headers",
                details: stringFromCount(viewModel.responseHeaders.count)
            )
        }.disabled(viewModel.responseHeaders.isEmpty)
        NavigationLink(destination: destinationResponseCookies) {
            MenuItem(
                icon: "lock",
                tintColor: .secondary,
                title: "Response Cookies",
                details: stringFromCount(viewModel.responseCookies.count)
            )
        }.disabled(viewModel.responseCookies.isEmpty)
    }

    @ViewBuilder
    private var sectionMetrics: some View {
        NavigationLink(destination: destinationMetrics) {
            MenuItem(
                icon: "clock.fill",
                tintColor: .orange,
                title: "Metrics",
                details: stringFromCount(viewModel.task.transactions.count)
            )
        }.disabled(!viewModel.task.hasMetrics)
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
            if #available(iOS 14.0, *) {
                Text(Image(systemName: viewModel.statusImageName))
                    .foregroundColor(viewModel.tintColor)
            } else {
                Image(systemName: viewModel.statusImageName)
                    .foregroundColor(viewModel.tintColor)
            }
            Text(viewModel.taskStatus)
                .lineLimit(1)
                .foregroundColor(viewModel.tintColor)
            Spacer()
            DurationLabel(viewModel: viewModel.duration)
        }.font(.headline)

        if viewModel.task.state == .failure, let description = viewModel.task.errorDebugDescription {
            NavigationLink(destination: destinaitionError) {
                Text(description)
                    .lineLimit(4)
                    .font(.callout)
            }
        }

        NavigationLink(destination: destinationRequestDetails) {
            (Text(viewModel.task.httpMethod ?? "GET").bold()
             + Text(" ") + Text(viewModel.task.url ?? "–"))
                .lineLimit(4)
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
            .padding(.bottom, 4)
            .padding(.top, -10)
        }
    }
    
    // MARK: - Destinations

    private var destinationRequestDetails: some View {
        NetworkInspectorRequestDetailsView(viewModel: .init(task: viewModel.task))
    }

    private var destinationRequestBody: some View {
        NetworkInspectorRequestView(viewModel: NetworkInspectorRequestViewModel(task: viewModel.task))
            .navigationBarTitle("Request Body")
    }
    
    private var destinationOriginalRequestHeaders: some View {
        NetworkDetailsView(title: "Request Headers", viewModel: viewModel.originalRequestHeadersViewModel)
    }
    
    private var destinationCurrentRequestHeaders: some View {
        NetworkDetailsView(title: "Request Headers", viewModel: viewModel.currentRequestHeadersViewModel)
    }
    
    private var destinationOriginalRequestCookies: some View {
        NetworkDetailsView(title: "Request Cookies", text: viewModel.originalRequestCookiesString)
    }

    private var destinationCurrentRequestCookies: some View {
        NetworkDetailsView(title: "Request Cookies", text: viewModel.currentRequestCookiesString)
    }

    private var destinationResponseCookies: some View {
        NetworkDetailsView(title: "Request Cookies", text: viewModel.responseCookiesString)
    }

    private var destinationResponseHeaders: some View {
        NetworkDetailsView(title: "Respons Header", viewModel: viewModel.responseHeadersViewModel)
    }

    private var destinationResponseBody: some View {
        NetworkInspectorResponseView(viewModel: NetworkInspectorResponseViewModel(task: viewModel.task))
            .navigationBarTitle("Response Body")
    }
    
    private var destinationMetrics: some View {
        NetworkInspectorMetricsTabView(viewModel: NetworkInspectorMetricsTabViewModel(task: viewModel.task))
            .navigationBarTitle("Metrics")
    }

    @ViewBuilder
    private var destinaitionError: some View {
        NetworkDetailsView(title: "Error", viewModel: KeyValueSectionViewModel.makeErrorDetails(for: viewModel.task, action: {}) ?? .empty())
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
                    .font(.system(size: 20))
                    .frame(width: 27, alignment: .leading)
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

private struct DurationLabel: View {
    @ObservedObject var viewModel: DurationViewModel

    var body: some View {
        if let duration = viewModel.duration {
            Text(duration)
                .backport.monospacedDigit()
                .lineLimit(1)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

#if DEBUG
struct NetworkInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                NetworkInspectorView(viewModel: .init(task: LoggerStore.preview.entity(for: .login)))
            }.previewDisplayName("Success")
            NavigationView {
                NetworkInspectorView(viewModel: .init(task: LoggerStore.preview.entity(for: .patchRepo)))
            }.previewDisplayName("Failure")
        }
    }
}
#endif

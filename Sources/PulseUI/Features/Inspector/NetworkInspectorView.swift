// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#warning("TODO: remove onClose")
#warning("TODO: tvOS enable scroll on left side")
#warning("TODO: tvOS fix transaction details UI")
#warning("TODO: rewrite TransactionsDeatilsView without KeyValueView")
#warning("TODO: macos show response body automatically when task finished loading")

struct NetworkInspectorView: View {
#if os(watchOS)
    @StateObject var viewModel: NetworkInspectorViewModel
#else
    @ObservedObject var viewModel: NetworkInspectorViewModel
#endif
    var onClose: (() -> Void)?

#if os(iOS)
    @State private var shareItems: ShareItems?
#endif
    
    @State private var isShowingCurrentRequest = false
    @State private var isEmptyLinkActive = false
    @State private var isResponseBodyLinkActive = false

    var body: some View {
        contents
#if os(iOS)
            .navigationBarItems(trailing: trailingNavigationBarItems)
            .navigationBarTitle(Text(viewModel.title), displayMode: .inline)
            .sheet(item: $shareItems, content: ShareView.init)
#else
            .backport.navigationTitle(viewModel.title)
#endif
#if os(macOS)
            .background(InvisibleNavigationLinks {
                NavigationLink.programmatic(isActive: $isEmptyLinkActive) { EmptyView () }
            })
            .onAppear {
                DispatchQueue.main.async {
                    if viewModel.task.responseBodySize > 0 {
                        isResponseBodyLinkActive = true
                    } else {
                        isEmptyLinkActive = true
                    }
                }
            }
#endif
    }

#if os(iOS) || os(macOS)
    var contents: some View {
#if os(macOS)
        List { _contents }
#else
        Form { _contents } // Cant't figure out how to disable collapsible sections
#endif
    }

    @ViewBuilder
    private var _contents: some View {
        Section {
            transferStatusView
#if os(macOS)
                .padding(.top)
#endif
        }
#if os(iOS)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
#endif

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
#elseif os(watchOS)
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
            Section {
                requestTypePickerView
                sectionRequest
            }
            if viewModel.task.state != .pending {
                Section {
                    sectionResponse
                }
            }
        }
    }
#elseif os(tvOS)
    var contents: some View {
        HStack {
            Form {
                Section {
                    transferStatusView
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)

                Section {
                    NetworkInspectorMetricsViewModel(task: viewModel.task).map {
                        TimingView(viewModel: $0.timingViewModel)
                    }
                }
            }
            .listStyle(.plain)
            .frame(width: 1000)
            Form {
                Section {
                    headerView
                }
                Section(header: Text("Request")) {
                    requestTypePickerView
                    sectionRequest
                }
                if viewModel.task.state != .pending {
                    Section(header: Text("Response")) {
                        sectionResponse
                    }
                    Section(header: Text("Transactions")) {
                        sectionMetrics
                    }
                }
            }
        }
    }
#endif

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
        NavigationLink(isActive: $isResponseBodyLinkActive, destination: { destinationResponseBody }) {
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

#if os(iOS) || os(tvOS) || os(macOS)
    @ViewBuilder
    private var sectionMetrics: some View {
#if os(iOS) || os(macOS)
        NavigationLink(destination: destinationMetrics) {
            MenuItem(
                icon: "clock.fill",
                tintColor: .orange,
                title: "Metrics",
                details: stringFromCount(viewModel.task.transactions.count)
            )
        }.disabled(!viewModel.task.hasMetrics)
#endif
        NetworkInspectorTransactionsListView(viewModel: .init(task: viewModel.task))
    }
#endif

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
#if !os(watchOS)
            if #available(iOS 14.0, tvOS 14.0, *) {
                Text(Image(systemName: viewModel.statusImageName))
                    .foregroundColor(viewModel.statusTintColor)
            } else {
                Image(systemName: viewModel.statusImageName)
                    .foregroundColor(viewModel.statusTintColor)
            }
#endif
            Text(viewModel.status)
#if os(watchOS)
                .lineLimit(3)
#else
                .lineLimit(1)
#endif
                .foregroundColor(viewModel.statusTintColor)
            Spacer()
            DurationLabel(viewModel: viewModel.durationViewModel)
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
        let picker = Picker("Request Type", selection: $isShowingCurrentRequest) {
            Text("Original").tag(false)
            Text("Current").tag(true)
        }
#if os(iOS)
        HStack {
            Text("Request Type")
            Spacer()
            picker
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .padding(.bottom, 4)
                .padding(.top, -10)
        }
#else
        picker
#endif
    }

    // MARK: - Destinations

    private var destinationRequestDetails: some View {
        NetworkInspectorRequestDetailsView(viewModel: .init(task: viewModel.task))
    }

#warning("TODO: remove these naviation titles")

    private var destinationRequestBody: some View {
        NetworkInspectorRequestView(viewModel: NetworkInspectorRequestViewModel(task: viewModel.task))
            .backport.navigationTitle("Request Body")
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
        NetworkDetailsView(title: "Response Header", viewModel: viewModel.responseHeadersViewModel)
    }

    private var destinationResponseBody: some View {
        NetworkInspectorResponseView(viewModel: NetworkInspectorResponseViewModel(task: viewModel.task))
            .backport.navigationTitle("Response Body")
    }

#if !os(watchOS)
    private var destinationMetrics: some View {
        NetworkInspectorMetricsTabView(viewModel: NetworkInspectorMetricsTabViewModel(task: viewModel.task))
            .backport.navigationTitle("Metrics")
    }
#endif

    @ViewBuilder
    private var destinaitionError: some View {
        NetworkDetailsView(title: "Error", viewModel: KeyValueSectionViewModel.makeErrorDetails(for: viewModel.task, action: {}) ?? .empty())
    }

    // MARK: - Helpers

    #warning("TODO: rewrite transaction details page on all platforms")
    #warning("TODO: instaed of NetworkInspectorTransactionsListView, use MenuItem + proper style of macOS")
    #warning("TODO: if there is only one operation, show it there? or remove NetworkLoad view entirely?")
    #warning("TOOD: rewrite NetworkTransactionDetailsView? show one-two columns based on size + rewrite without KeyValueView")
    #warning("TODO: macOS use pro version of the text viewer")
    #warning("TODO: macos remvoe hor/vert switch")

    private struct MenuItem: View {
        let icon: String
        let tintColor: Color
        let title: String
        let details: String
        
        var body: some View {
#if os(watchOS)
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                    Text(details).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: icon)
                    .foregroundColor(tintColor)
                    .font(.system(size: 18))
                    .frame(width: 18, alignment: .trailing)
            }
#elseif os(tvOS)
            HStack {
                Text(title)
                Spacer()
                Text(details).foregroundColor(.secondary)
            }
#else
            HStack {
                Image(systemName: icon)
                    .foregroundColor(tintColor)
                    .font(.system(size: 20))
                    .frame(width: 27, alignment: .leading)
                Text(title)
                Spacer()
                Text(details).foregroundColor(.secondary)
            }
#endif
        }
    }

#if os(iOS)
    @ViewBuilder
    private var trailingNavigationBarItems: some View {
        HStack {
            if let viewModel = viewModel.pinViewModel {
                PinButton(viewModel: viewModel, isTextNeeded: false)
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
#endif
}

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

#if os(tvOS)
private let spacing: CGFloat = 20
#else
private let spacing: CGFloat? = nil
#endif

#if DEBUG
struct NetworkInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
#if os(macOS)
            if #available(macOS 13.0, *) {
                NavigationStack {
                    NetworkInspectorView(viewModel: .init(task: LoggerStore.preview.entity(for: .login)))
                }.previewLayout(.fixed(width: MainView.contentColumnWidth, height: 800))
            }
#else
            NavigationView {
                NetworkInspectorView(viewModel: .init(task: LoggerStore.preview.entity(for: .login)))
            }.previewDisplayName("Success")

            NavigationView {
                NetworkInspectorView(viewModel: .init(task: LoggerStore.preview.entity(for: .patchRepo)))
            }.previewDisplayName("Failure")
#endif
        }
    }
}
#endif

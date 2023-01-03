// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#warning("TODO: fix invalid linelimit on watchOS")
#warning("TODO: remove onClose")

#if os(iOS) || os(watchOS) || os(tvOS)

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
    
#if os(iOS) || os(watchOS)
    var body: some View {
        contents
#if os(iOS)
            .navigationBarItems(trailing: trailingNavigationBarItems)
            .navigationBarTitle(Text(viewModel.title), displayMode: .inline)
            .sheet(item: $shareItems, content: ShareView.init)
#else
            .navigationTitle(viewModel.title)
#endif
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
#if os(watchOS)
            Section {
                requestTypePickerView
                sectionRequest
            }
#else
            Section(header: requestTypePickerView) {
                sectionRequest
            }
#endif
            if viewModel.task.state != .pending {
                Section {
                    sectionResponse
                }
#if !os(watchOS)
                Section {
                    sectionMetrics
                }
#endif
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

    #warning("TODO: it does have Metrics?")

#if !os(watchOS)
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

#warning("TODO: remove .spacing")

    @ViewBuilder
    var headerView: some View {
        HStack {
#if !os(watchOS)
            if #available(iOS 14.0, *) {
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

#if !os(watchOS)
    private var destinationMetrics: some View {
        NetworkInspectorMetricsTabView(viewModel: NetworkInspectorMetricsTabViewModel(task: viewModel.task))
            .navigationBarTitle("Metrics")
    }
#endif

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

#else
    var body: some View {
        NetworkInspectorSummaryView(viewModel: viewModel.summaryViewModel)
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

#endif

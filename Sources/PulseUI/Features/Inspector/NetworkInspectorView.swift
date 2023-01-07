// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#warning("TODO: display full date somewhere")
#warning("TODO: add task rype somewhere")
#warning("TODO: add View Raw + cURL descriootion")
#warning("TODO: rework where (Cache) is displayed")

#warning("TODO: when highlighting textview use prepareUpdate and commitUpdates")
#warning("TODO: fix state management at least on the top level")
#warning("TODO: rework metrics")
#warning("TODO: find better icons")
#warning("TODO: simplify response views to not show progress (or remove entirely?")



#warning("TODO: tvOS enable scroll on left side")
#warning("TODO: tvOS fix transaction details UI")
#warning("TODO: rewrite TransactionsDeatilsView without KeyValueView")
#warning("TODO: macos show response body automatically when task finished loading")
#warning("TODO: add sharing on watchOS")

#warning("TODO: test everything with Self._printChanges() for performance")

#warning("TODO: render request body sring monospaced")

struct NetworkInspectorView: View {
#if os(watchOS)
    @StateObject var viewModel: NetworkInspectorViewModel
#else
    @ObservedObject var viewModel: NetworkInspectorViewModel
#endif

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
            viewModel.statusSectionViewModel.map(NetworkRequestStatusSectionView.init)
        }
        Section(header: requestTypePicker) {
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
                viewModel.statusSectionViewModel.map(NetworkRequestStatusSectionView.init)
            }
            Section {
                requestTypePicker
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

#warning("TODO: what if not available?")
                Section {
                    TimingView(viewModel: .init(task: viewModel.task))
                }
            }
            .listStyle(.plain)
            .frame(width: 1000)
            Form {
                Section {
                    viewModel.statusSectionViewModel.map(NetworkRequestStatusSectionView.init)
                }
                Section(header: Text("Request")) {
                    requestTypePicker
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
        viewModel.requestBodyViewModel.map(NetworkRequestBodyCell.init)
        if !isShowingCurrentRequest {
            viewModel.originalRequestHeadersViewModel.map(NetworkHeadersCell.init)
            viewModel.originalRequestCookiesViewModel.map(NetworkCookiesCell.init)
        } else {
            viewModel.currentRequestHeadersViewModel.map(NetworkHeadersCell.init)
            viewModel.currentRequestCookiesViewModel.map(NetworkCookiesCell.init)
        }
    }

    @ViewBuilder
    private var sectionResponse: some View {
        viewModel.responseBodyViewModel.map(NetworkResponseBodyCell.init)
        viewModel.responseHeadersViewModel.map(NetworkHeadersCell.init)
        viewModel.responseCookiesViewModel.map(NetworkCookiesCell.init)
    }

#if os(iOS) || os(tvOS) || os(macOS)
    @ViewBuilder
    private var sectionMetrics: some View {
#if os(iOS) || os(macOS)
        NavigationLink(destination: destinationMetrics) {
            NetworkMenuCell(
                icon: "clock.fill",
                tintColor: .orange,
                title: "Metrics",
                details: ""
            )
        }.disabled(!viewModel.task.hasMetrics)
#endif
        NetworkCURLCell(task: viewModel.task)
    }
#endif

    // MARK: - Subviews

    #warning("TODO: this fallback isn't ideal on other paltforms only on ios")

    @ViewBuilder
    private var transferStatusView: some View {
        ZStack {
            NetworkInspectorTransferInfoView(viewModel: .init(empty: true))
                .hidden()
                .backport.hideAccessibility()
            if let transfer = viewModel.transferViewModel {
                NetworkInspectorTransferInfoView(viewModel: transfer)
            } else if let progress = viewModel.progressViewModel {
                SpinnerView(viewModel: progress)
            } else if let status = viewModel.statusSectionViewModel?.status {
                // Fallback in case metrics are disabled
                Image(systemName: status.imageName)
                    .foregroundColor(status.tintColor)
                    .font(.system(size: 64))
            } // Should never happen
        }
    }

    @ViewBuilder
    private var requestTypePicker: some View {
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

#warning("TODO: remove these naviation titles")

#if !os(watchOS)
    private var destinationMetrics: some View {
        NetworkInspectorMetricsViewModel(task: viewModel.task).map {
            NetworkInspectorMetricsView(viewModel: $0)
                .backport.navigationTitle("Metrics")
        }
    }
#endif

    // MARK: - Helpers

    #warning("TODO: rewrite transaction details page on all platforms")
    #warning("TODO: instaed of NetworkInspectorTransactionsListView, use MenuItem + proper style of macOS")
    #warning("TODO: if there is only one operation, show it there? or remove NetworkLoad view entirely?")
    #warning("TOOD: rewrite NetworkTransactionDetailsView? show one-two columns based on size + rewrite without KeyValueView")
    #warning("TODO: macOS use pro version of the text viewer")
    #warning("TODO: macos remvoe hor/vert switch")

#if os(iOS)
    @ViewBuilder
    private var trailingNavigationBarItems: some View {
        HStack {
            if #available(iOS 14, *) {
                Menu(content: {
                    AttributedStringShareMenu(shareItems: $shareItems) {
                        TextRenderer().render(viewModel.task, content: .sharing)
                    }
                    Button(action: { shareItems = ShareItems([viewModel.task.cURLDescription()]) }) {
                        Label("Share as cURL", systemImage: "square.and.arrow.up")
                    }
                }, label: {
                    Image(systemName: "square.and.arrow.up")
                })
                Menu(content: {
                    NetworkMessageContextMenu(task: viewModel.task, sharedItems: $shareItems)
                }, label: {
                    Image(systemName: "ellipsis.circle")
                })
            }
        }
    }
#endif
}

private func stringFromByteCount(_ count: Int64) -> String {
    guard count > 0 else {
        return ""
    }
    return ByteCountFormatter.string(fromByteCount: count)
}

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

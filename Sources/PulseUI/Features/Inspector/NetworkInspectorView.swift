// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#warning("TODO: tvOS enable scroll on left side")
#warning("TODO: tvOS fix transaction details UI")
#warning("TODO: macos show response body automatically when task finished loading")
#warning("TODO: add sharing on watchOS")
#warning("TODO: tvOS fix layour for text views")
#warning("TODO: tvOS remove force unwrap")

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

    var body: some View {
        contents
            .backport.inlineNavigationTitle(viewModel.title)
#if os(iOS)
            .navigationBarItems(trailing: trailingNavigationBarItems)
            .sheet(item: $shareItems, content: ShareView.init)
#endif
    }

#if os(iOS) || os(macOS)
    var contents: some View {
#if os(macOS)
        List { _contents }
#else
        Form { _contents } // Can't figure out how to disable collapsible sections
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
        Section { viewModel.statusSectionViewModel.map(NetworkRequestStatusSectionView.init) }
        Section { sectionRequest } header: { requestTypePicker }
        if viewModel.task.state != .pending {
            Section { sectionResponse }
            Section { sectionMetrics }
        }
    }
#elseif os(watchOS)
    var contents: some View {
        List {
            Section { viewModel.statusSectionViewModel.map(NetworkRequestStatusSectionView.init) }
            Section {
                transerInfoSentView
                requestTypePicker
                sectionRequest
            }
            if viewModel.task.state != .pending {
                Section {
                    transerInfoReceivedView
                    sectionResponse
                }
                Section { sectionMetrics }
            }
        }
        .toolbar {
            if #available(watchOS 9.0, *), let url = ShareService.share(viewModel.task, as: .html).items.first as? URL {
                ShareLink(item: url)
            }
        }
    }

#warning("TODO: refactor")

    private var transerInfoSentView: some View {
        viewModel.transferViewModel.map {
            NetworkInspectorTransferInfoView(viewModel: $0)
                .hideReceived()
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .padding(.top, 8)
                .padding(.bottom, 16)
        }
    }

    private var transerInfoReceivedView: some View {
        viewModel.transferViewModel.map {
            NetworkInspectorTransferInfoView(viewModel: $0)
                .hideReceived()
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .padding(.top, 8)
                .padding(.bottom, 16)
        }
    }
#elseif os(tvOS)
    var contents: some View {
        HStack {
            Form {
                Section {
                    viewModel.statusSectionViewModel.map(NetworkRequestStatusSectionView.init)
                }
                Section {
                    requestTypePicker
                    sectionRequest
                } header: { Text("Request") }
                if viewModel.task.state != .pending {
                    Section { sectionResponse } header: { Text("Response") }
                    
                }
                Section { sectionMetrics } header: { Text("Transactions") }
            }
            .frame(width: 740)
            Form {
                Section {
                    transferStatusView.padding(.bottom, 32)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                NetworkInspectorMetricsViewModel(task: viewModel.task)
                    .map(NetworkInspectorMetricsView.init)
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

    @ViewBuilder
    private var sectionMetrics: some View {
#if os(iOS) || os(macOS) || os(watchOS)
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

    // MARK: - Subviews

    #warning("TODO: this fallback isn't ideal on other paltforms only on ios")

#if os(iOS) || os(macOS) || os(tvOS)
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
#endif

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

    private var destinationMetrics: some View {
        NetworkInspectorMetricsViewModel(task: viewModel.task).map {
            NetworkInspectorMetricsView(viewModel: $0)
        }
    }

    // MARK: - Helpers

#warning("TODO: macOS use pro version of the text viewer")
#warning("TODO: macos remove hor/vert switch")

#if os(iOS)
    @ViewBuilder
    private var trailingNavigationBarItems: some View {
        HStack {
            if #available(iOS 14, *) {
                Menu(content: {
                    AttributedStringShareMenu(shareItems: $shareItems) {
                        TextRenderer(options: .sharing).render(viewModel.task, content: .sharing)
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
                }.previewLayout(.fixed(width: ConsoleView.contentColumnWidth, height: 800))
            }
#else
            NavigationView {
                NetworkInspectorView(viewModel: .init(task: LoggerStore.preview.entity(for: .login)))
            }
            .navigationViewStyle(.stack)
            .previewDisplayName("Success")

            NavigationView {
                NetworkInspectorView(viewModel: .init(task: LoggerStore.preview.entity(for: .patchRepo)))
            }
            .navigationViewStyle(.stack)
            .previewDisplayName("Failure")
#endif
        }
    }
}
#endif

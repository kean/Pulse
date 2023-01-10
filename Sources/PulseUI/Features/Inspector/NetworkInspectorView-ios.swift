// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS)

struct NetworkInspectorView: View {
    @ObservedObject var viewModel: NetworkInspectorViewModel

    @State private var shareItems: ShareItems?
    @State private var isCurrentRequest = false

    var body: some View {
        Form {
            contents
        }
        .backport.inlineNavigationTitle(viewModel.title)
        .navigationBarItems(trailing: trailingNavigationBarItems)
        .sheet(item: $shareItems, content: ShareView.init)
    }

    @ViewBuilder
    private var contents: some View {
        Section {
            transferStatusView
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)

        Section {
            viewModel.statusSectionViewModel.map(NetworkRequestStatusSectionView.init)
        }

        Section {
            NetworkInspectorSectionRequest(viewModel: viewModel, isCurrentRequest: isCurrentRequest)
        } header: { requestTypePicker }

        if viewModel.task.state != .pending {
            Section { sectionResponse }
            Section { sectionMetrics }
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
        NetworkMetricsCell(task: viewModel.task)
        NetworkCURLCell(task: viewModel.task)
    }

    // MARK: - Subviews

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
        let picker = Picker("Request Type", selection: $isCurrentRequest) {
            Text("Original").tag(false)
            Text("Current").tag(true)
        }
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
    }

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

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(macOS)

struct NetworkInspectorView: View {
    @ObservedObject var viewModel: NetworkInspectorViewModel

    @State private var isShowingCurrentRequest = false

    var body: some View {
        List {
            contents
        }
        .backport.inlineNavigationTitle(viewModel.title)
        .toolbar {
            if #available(macOS 13, *),
               let url = ShareService.share(viewModel.task, as: .html).items.first as? URL {
                ShareLink(item: url)
            }
        }
    }

    @ViewBuilder
    private var contents: some View {
        Section {
            transferStatusView
                .padding(.vertical)
        }
        Section {
            viewModel.statusSectionViewModel.map(NetworkRequestStatusSectionView.init)
        }
        Section {
            sectionRequest
        } header: {
            requestTypePicker
        }
        if viewModel.task.state != .pending {
            Section { sectionResponse }
            Section { sectionMetrics }
        }
    }

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
        Picker("Request Type", selection: $isShowingCurrentRequest) {
            Text("Original").tag(false)
            Text("Current").tag(true)
        }
    }
}

#if DEBUG
struct NetworkInspectorView_Previews: PreviewProvider {
    static var previews: some View {
            if #available(macOS 13.0, *) {
                NavigationStack {
                    NetworkInspectorView(viewModel: .init(task: LoggerStore.preview.entity(for: .login)))
                }.previewLayout(.fixed(width: ConsoleView.contentColumnWidth, height: 800))
            }
        }
}
#endif

#endif

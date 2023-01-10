// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(watchOS)

struct NetworkInspectorView: View {
    @StateObject var viewModel: NetworkInspectorViewModel

    @State private var isShowingCurrentRequest = false

    var body: some View {
        contents
            .backport.inlineNavigationTitle(viewModel.title)
            .toolbar {
                if #available(watchOS 9, *),
                   let url = ShareService.share(viewModel.task, as: .html).items.first as? URL {
                    ShareLink(item: url)
                }
            }
    }

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
    }

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
        NavigationView {
            NetworkInspectorView(viewModel: .init(task: LoggerStore.preview.entity(for: .login)))
        }.navigationViewStyle(.stack)
    }
}
#endif

#endif

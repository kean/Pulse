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

    @State private var isCurrentRequest = false

    var body: some View {
        contents
            .backport.inlineNavigationTitle(viewModel.title)
            .toolbar {
                if #available(watchOS 9, *), let url = viewModel.shareTaskAsHTML() {
                    ShareLink(item: url)
                }
            }
    }

    var contents: some View {
        List {
            Section { viewModel.statusSectionViewModel.map(NetworkRequestStatusSectionView.init) }
            Section {
                transerInfoSentView
                NetworkInspectorRequestTypePicker(isCurrentRequest: $isCurrentRequest)
                NetworkInspectorSectionRequest(viewModel: viewModel, isCurrentRequest: isCurrentRequest)
            }
            if viewModel.task.state != .pending {
                Section {
                    transerInfoReceivedView
                    NetworkInspectorSectionResponse(viewModel: viewModel)
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
    private var sectionMetrics: some View {
        NetworkMetricsCell(task: viewModel.task)
        NetworkCURLCell(task: viewModel.task)
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

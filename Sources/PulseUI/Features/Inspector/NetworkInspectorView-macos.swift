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

    @State private var isCurrentRequest = false

    var body: some View {
        List {
            contents
        }
        .backport.inlineNavigationTitle(viewModel.title)
        .toolbar {
            if #available(macOS 13, *), let url = viewModel.shareTaskAsHTML() {
                ShareLink(item: url)
            }
        }
    }

    @ViewBuilder
    private var contents: some View {
        Section {
            viewModel.statusSectionViewModel.map(NetworkRequestStatusSectionView.init)
        }
        Section {
            NetworkInspectorSectionTransferStatus(viewModel: viewModel)
                .padding(.bottom, 6)
        }
        Section {
            NetworkInspectorSectionRequest(viewModel: viewModel, isCurrentRequest: isCurrentRequest)
        } header: {
            NetworkInspectorRequestTypePicker(isCurrentRequest: $isCurrentRequest)
        }
        if viewModel.task.state != .pending {
            Section {
                NetworkInspectorSectionResponse(viewModel: viewModel)
            }
            Section {
                NetworkMetricsCell(task: viewModel.task)
                NetworkCURLCell(task: viewModel.task)
            }
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

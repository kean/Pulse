// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(macOS)

struct NetworkInspectorView: View {
    @StateObject var viewModel: NetworkInspectorViewModel

    @State private var isCurrentRequest = false

    var body: some View {
        List {
            contents
        }
        .inlineNavigationTitle(viewModel.title)
        .toolbar {
            if #available(macOS 13, *), let url = viewModel.shareTaskAsHTML() {
                ShareLink(item: url)
            }
        }
    }

    @ViewBuilder
    private var contents: some View {
        Section {
            NetworkInspectorSectionTransferStatus(viewModel: viewModel)
        }
        Section {
            viewModel.statusSectionViewModel.map(NetworkRequestStatusSectionView.init)
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

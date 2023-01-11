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
            .inlineNavigationTitle(viewModel.title)
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
                makeTransferInfo(isReceivedHidden: true)
                NetworkInspectorRequestTypePicker(isCurrentRequest: $isCurrentRequest)
                NetworkInspectorSectionRequest(viewModel: viewModel, isCurrentRequest: isCurrentRequest)
            }
            if viewModel.task.state != .pending {
                Section {
                    makeTransferInfo(isSentHidden: true)
                    NetworkInspectorSectionResponse(viewModel: viewModel)
                }
                Section {
                    NetworkMetricsCell(task: viewModel.task)
                    NetworkCURLCell(task: viewModel.task)
                }
            }
        }
    }

    private func makeTransferInfo(isSentHidden: Bool = false, isReceivedHidden: Bool = false) -> some View {
        viewModel.transferViewModel.map {
            NetworkInspectorTransferInfoView(viewModel: $0, isSentHidden: isSentHidden, isReceivedHidden: isReceivedHidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .padding(.top, 8)
                .padding(.bottom, 16)
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

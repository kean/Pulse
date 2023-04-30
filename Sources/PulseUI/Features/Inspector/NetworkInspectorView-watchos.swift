// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(watchOS)

import SwiftUI
import CoreData
import Pulse
import Combine

struct NetworkInspectorView: View {
    @ObservedObject var task: NetworkTaskEntity

    @State private var isCurrentRequest = false

    var body: some View {
        contents
            .inlineNavigationTitle(task.title)
//            .toolbar {
//                if #available(watchOS 9, *), let url = viewModel.shareTaskAsHTML() {
//                    ShareLink(item: url)
//                }
//            }
    }

    var contents: some View {
        List {
            Section {
                NetworkRequestStatusSectionView(viewModel: .init(task: task))
            }
            Section {
                makeTransferInfo(isReceivedHidden: true)
                NetworkInspectorRequestTypePicker(isCurrentRequest: $isCurrentRequest)
                NetworkInspectorView.makeRequestSection(task: task, isCurrentRequest: isCurrentRequest)
            }
            if task.state != .pending {
                Section {
                    makeTransferInfo(isSentHidden: true)
                    NetworkInspectorView.makeResponseSection(task: task)
                }
                Section {
                    NetworkMetricsCell(task: task)
                    NetworkCURLCell(task: task)
                }
            }
        }
    }

    @ViewBuilder
    private func makeTransferInfo(isSentHidden: Bool = false, isReceivedHidden: Bool = false) -> some View {
        if task.hasMetrics {
            NetworkInspectorTransferInfoView(viewModel: .init(task: task), isSentHidden: isSentHidden, isReceivedHidden: isReceivedHidden)
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
            NetworkInspectorView(task: LoggerStore.preview.entity(for: .login))
        }.navigationViewStyle(.stack)
    }
}
#endif

#endif

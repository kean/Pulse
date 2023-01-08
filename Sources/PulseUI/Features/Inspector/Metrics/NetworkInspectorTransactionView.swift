// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData

struct NetworkInspectorTransactionView: View {
    @ObservedObject var viewModel: NetworkInspectorTransactionViewModel

    var body: some View {
        Section(header: Text(viewModel.title)) {
            NetworkRequestStatusCell(viewModel: viewModel.statusViewModel)
            viewModel.timingViewModel.map(TimingView.init)
#if os(iOS) || os(macOS)
            viewModel.transferSizeViewModel.map {
                NetworkInspectorTransferInfoView(viewModel: $0)
                    .hideDivider()
                    .padding(.vertical, 8)
            }
#endif
            NetworkRequestInfoCell(viewModel: viewModel.requestViewModel)
            NavigationLink(destination: destintionTransactionDetails) {
                Text("Transaction Details")
            }
        }
    }

    private var destintionTransactionDetails: some View {
        NetworkDetailsView(title: "Transaction Details") { viewModel.details() }
    }
}

// MARK: - ViewModel

final class NetworkInspectorTransactionViewModel: ObservableObject, Identifiable {
    let id: NSManagedObjectID
    let title: String
    let statusViewModel: NetworkRequestStatusCellModel
    let timingViewModel: TimingViewModel?
    let requestViewModel: NetworkRequestInfoCellViewModel
    let transferSizeViewModel: NetworkInspectorTransferInfoViewModel?
    let details: () -> NSAttributedString

    init(transaction: NetworkTransactionMetricsEntity, task: NetworkTaskEntity) {
        self.id = transaction.objectID
        self.title = transaction.fetchType.title
        self.statusViewModel = NetworkRequestStatusCellModel(transaction: transaction)
        self.requestViewModel = NetworkRequestInfoCellViewModel(transaction: transaction)
        self.timingViewModel = TimingViewModel(transaction: transaction, task: task)

        if transaction.fetchType == .networkLoad {
            self.transferSizeViewModel = NetworkInspectorTransferInfoViewModel(transferSize: transaction.transferSize)
        } else {
            self.transferSizeViewModel = nil
        }

        self.details = {
            let renderer = TextRenderer(options: .sharing)
            let sections = KeyValueSectionViewModel.makeDetails(for: transaction)
            return renderer.joined(sections.map { renderer.render($0) })
        }
    }
}

#if DEBUG
struct NetworkInspectorTransactionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            List {
                ForEach(mockTask.orderedTransactions, id: \.index) {
                    NetworkInspectorTransactionView(viewModel: .init(transaction: $0, task: mockTask))
                }
            }
        }
#if os(watchOS)
        .navigationViewStyle(.stack)
#endif
    }
}

private let mockTask = LoggerStore.preview.entity(for: .createAPI)

#endif

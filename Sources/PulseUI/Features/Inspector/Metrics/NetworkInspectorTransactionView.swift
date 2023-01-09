// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData

#warning("TODO: show download size on other platforms")

struct NetworkInspectorTransactionView: View {
    @ObservedObject var viewModel: NetworkInspectorTransactionViewModel

    var body: some View {
        Section(header: Text(viewModel.title)) {
            NetworkRequestStatusCell(viewModel: viewModel.statusViewModel)
            viewModel.timingViewModel.map(TimingView.init)
#if os(iOS) || os(macOS)
            NavigationLink(destination: destintionTransactionDetails) {
                if #available(iOS 15, tvOS 15, macOS 12, *), let size = viewModel.transferSizeViewModel {
                    transferSizeView(size: size)
                } else {
                    Text("Transaction Details")
                }
            }
#else
            NavigationLink(destination: destintionTransactionDetails) {
                Text("Transaction Details")
            }
#endif
            NetworkRequestInfoCell(viewModel: viewModel.requestViewModel)
        }
    }

    @available(iOS 15, tvOS 15, watchOS 8, macOS 12, *)
    @ViewBuilder
    private func transferSizeView(size: NetworkInspectorTransferInfoViewModel) -> some View {
        HStack {
            VStack(spacing: 8) {
                HStack {
                    Text("Details")
                    Spacer()
                    (Text(Image(systemName: "arrow.down.circle")) +
                     Text(" ") +
                     Text(size.totalBytesSent) +
                     Text("   ") +
                     Text(Image(systemName: "arrow.up.circle")) +
                     Text(" ") +
                     Text(size.totalBytesReceived))
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                }
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

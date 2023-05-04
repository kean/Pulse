// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData

struct NetworkInspectorTransactionView: View {
    @ObservedObject var viewModel: NetworkInspectorTransactionViewModel

    var body: some View {
        Section {
            contents
        }
    }
    
    @ViewBuilder
    private var contents: some View {
        NetworkRequestStatusCell(viewModel: viewModel.statusViewModel)
#if os(macOS)
            .padding(.bottom, 8)
#endif
        viewModel.timingViewModel.map(TimingView.init)
        NavigationLink(destination: destintionTransactionDetails) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.title)
                if #available(iOS 15, *), let size = viewModel.transferSizeViewModel {
                    transferSizeView(size: size)
                }
            }
        }
        NetworkRequestInfoCell(viewModel: viewModel.requestViewModel)
    }
    
    @available(iOS 15, *)
    private func transferSizeView(size: NetworkInspectorTransferInfoViewModel) -> some View {
        let font = TextHelper().font(style: .init(role: .subheadline, style: .monospacedDigital, width: .condensed))
        return (Text(Image(systemName: "arrow.down.circle")) +
                Text(" ") +
         Text(size.totalBytesSent) +
         Text("  ") +
         Text(Image(systemName: "arrow.up.circle")) +
         Text(" ") +
         Text(size.totalBytesReceived))
        .lineLimit(1)
        .font(Font(font))
        .foregroundColor(.secondary)
    }

    private var destintionTransactionDetails: some View {
        NetworkDetailsView(title: "Transaction Details") { viewModel.details() }
    }
}

// MARK: - ViewModel

final class NetworkInspectorTransactionViewModel: ObservableObject, Identifiable {
    let id: NSManagedObjectID
    let title: String
    let transaction: NetworkTransactionMetricsEntity
    let statusViewModel: NetworkRequestStatusCellModel
    let timingViewModel: TimingViewModel?
    let requestViewModel: NetworkRequestInfoCellViewModel
    let transferSizeViewModel: NetworkInspectorTransferInfoViewModel?
    let details: () -> NSAttributedString

    init(transaction: NetworkTransactionMetricsEntity, task: NetworkTaskEntity) {
        self.id = transaction.objectID
        self.title = transaction.fetchType.title
        self.transaction = transaction
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
            renderer.render(sections)
            return renderer.make()
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
            }.frame(width: 600)
        }
#if os(macOS)
            .frame(width: 1000, height: 1000)
#endif
#if os(watchOS)
        .navigationViewStyle(.stack)
#endif
    }
}

private let mockTask = LoggerStore.preview.entity(for: .createAPI)

#endif

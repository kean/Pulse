// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#warning("TODO: dont show empty sections (headers/cookies) - not enough space here")
#warning("TODO: different icons for headers and cookies")
#warning("TODO: fix background highlight on clicking on cell e.g. response")

#if os(iOS) || os(macOS) || os(tvOS)

struct NetworkInspectorTransactionView: View {
    @ObservedObject var viewModel: NetworkInspectorTransactionViewModel

    var body: some View {
        Section(header: Text(viewModel.title)) {
            NetworkRequestStatusSectionView(viewModel: viewModel.statusSectionViewModel)
            viewModel.timingViewModel.map(TimingView.init)
            viewModel.transferSizeViewModel.map {
                NetworkInspectorTransferInfoView(viewModel: $0)
                    .padding(.vertical, 8)
            }
            NetworkHeadersCell(viewModel: viewModel.requestHeadersViewModel)
            NetworkHeadersCell(viewModel: viewModel.responseHeadersViewModel)
        }
    }
}

// MARK: - ViewModel

final class NetworkInspectorTransactionViewModel: ObservableObject {
    let title: String
    let statusSectionViewModel: NetworkRequestStatusSectionViewModel
    let timingViewModel: TimingViewModel?
    let requestHeadersViewModel: NetworkHeadersCellViewModel
    let responseHeadersViewModel: NetworkHeadersCellViewModel

    @Published var isOriginalRequestHeadersLinkActive = false
    @Published var isResponseHeadersLinkActive = false

    let details: NetworkMetricsDetailsViewModel?
    let transferSizeViewModel: NetworkInspectorTransferInfoViewModel?

    private let transaction: NetworkTransactionMetricsEntity

    init(transaction: NetworkTransactionMetricsEntity, task: NetworkTaskEntity) {
        self.title = transaction.fetchType.title
        self.statusSectionViewModel = NetworkRequestStatusSectionViewModel(transaction: transaction)
        self.details = NetworkMetricsDetailsViewModel(metrics: transaction)
        self.timingViewModel = TimingViewModel(transaction: transaction, task: task)
        self.requestHeadersViewModel = NetworkHeadersCellViewModel(title: "Request Headers", headers: transaction.request.headers)
        self.responseHeadersViewModel = NetworkHeadersCellViewModel(title: "Response Headers", headers: transaction.response?.headers)

        if transaction.fetchType == .networkLoad {
            self.transferSizeViewModel = NetworkInspectorTransferInfoViewModel(transferSize: transaction.transferSize, isUpload: false)
        } else {
            self.transferSizeViewModel = nil
        }
        self.transaction = transaction
    }
}

#if DEBUG
struct NetworkInspectorTransactionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            List {
                NetworkInspectorTransactionView(viewModel: mockModel)
            }
        }
    }
}

private let mockModel = NetworkInspectorTransactionViewModel(transaction: mockTask.orderedTransactions.last!, task: mockTask)

private let mockTask = LoggerStore.preview.entity(for: .login)

#endif

#endif

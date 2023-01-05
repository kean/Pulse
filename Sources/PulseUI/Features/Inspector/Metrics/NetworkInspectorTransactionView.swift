// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#warning("TODO: display name of operation somewhere")
#warning("TODO: dont show empty sections (headers/cookies) - not enough space here")
#warning("TODO: different icons for headers and cookies")
#warning("TODO: fix background highligt on clicking on cell e.g. response")

#if os(iOS) || os(macOS) || os(tvOS)

struct NetworkInspectorTransactionView: View {
    @ObservedObject var viewModel: NetworkInspectorTransactionViewModel

    var body: some View {
        NetworkRequestStatusSectionView(viewModel: viewModel.statusSectionViewModel)
        viewModel.timingViewModel.map(TimingView.init)
        viewModel.transferSizeViewModel.map {
            NetworkInspectorTransferInfoView(viewModel: $0)
                .padding(.vertical, 8)
        }
        NetworkHeadersCell(viewModel: viewModel.requestHeadersViewModel)
        NetworkCookiesCell(viewModel: viewModel.responseCookiesViewModel)
        NetworkHeadersCell(viewModel: viewModel.responseHeadersViewModel)
        NetworkCookiesCell(viewModel: viewModel.responseCookiesViewModel)
        NavigationLink(destination: destinationTiming) {
            NetworkMenuCell(icon: "clock", tintColor: .orange, title: "Timing Info")
        }
    }

    private var destinationTiming: some View {
        NetworkDetailsView(title: "Timing Details") { viewModel.timingSummary }
    }
}

// MARK: - ViewModel

final class NetworkInspectorTransactionViewModel: ObservableObject {
    let statusSectionViewModel: NetworkRequestStatusSectionViewModel
    let timingViewModel: TimingViewModel?
    let requestHeadersViewModel: NetworkHeadersCellViewModel
    let requestCookiesViewModel: NetworkCookiesCellViewModel
    let responseHeadersViewModel: NetworkHeadersCellViewModel
    let responseCookiesViewModel: NetworkCookiesCellViewModel
    lazy var timingSummary = KeyValueSectionViewModel.makeTiming(for: transaction)

    @Published var isOriginalRequestHeadersLinkActive = false
    @Published var isResponseHeadersLinkActive = false

    let details: NetworkMetricsDetailsViewModel?
    let transferSizeViewModel: NetworkInspectorTransferInfoViewModel?

    private let transaction: NetworkTransactionMetricsEntity

    init(transaction: NetworkTransactionMetricsEntity, task: NetworkTaskEntity) {
        let url = transaction.request.url.flatMap(URL.init)

        self.statusSectionViewModel = NetworkRequestStatusSectionViewModel(transaction: transaction)
        self.details = NetworkMetricsDetailsViewModel(metrics: transaction)
        self.timingViewModel = TimingViewModel(transaction: transaction, task: task)
        self.requestHeadersViewModel = NetworkHeadersCellViewModel(title: "Request Headers", headers: transaction.request.headers)
        self.requestCookiesViewModel = NetworkCookiesCellViewModel(title: "Request Cookies", headers: transaction.request.headers, url: url)
        self.responseHeadersViewModel = NetworkHeadersCellViewModel(title: "Response Headers", headers: transaction.response?.headers)
        self.responseCookiesViewModel = NetworkCookiesCellViewModel(title: "Response Cookies", headers: transaction.response?.headers, url: url)

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
                Section {
                    NetworkInspectorTransactionView(viewModel: mockModel)
                        .background(Color(UXColor.systemBackground))
                        .backport.navigationTitle("Network Load")
                }
            }
        }
    }
}

private let mockModel = NetworkInspectorTransactionViewModel(transaction: mockTask.orderedTransactions.last!, task: mockTask)

private let mockTask = LoggerStore.preview.entity(for: .login)

#endif

#endif

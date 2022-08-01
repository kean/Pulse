// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(iOS) || os(macOS)

// MARK: - View

struct NetworkInspectorTransactionView: View {
    @ObservedObject var viewModel: NetworkInspectorTransactionViewModel

    var body: some View {
        ScrollView {
            VStack {
                if let timingViewModel = viewModel.timingViewModel {
                    TimingView(viewModel: timingViewModel)
                }
                Section(header: LargeSectionHeader(title: "Request")) {
                    KeyValueGridView(items: [
                        viewModel.requestSummary,
                        viewModel.requestHeaders,
                        viewModel.requestParameters
                    ].compactMap { $0 })
                }
                Section(header: LargeSectionHeader(title: "Response")) {
                    KeyValueGridView(items: [
                        viewModel.responseSummary,
                        viewModel.responseHeaders
                    ])
                }
                if let details = viewModel.details {
                    Section(header: LargeSectionHeader(title: "Details")) {
                        KeyValueGridView(items: details.sections)
                    }
                }
                Section(header: LargeSectionHeader(title: "Timing")) {
                    KeyValueSectionView(viewModel: viewModel.timingSummary)
                }
            }
            .padding(16)
        }
        .background(links)
    }

    @ViewBuilder
    private var links: some View {
        InvisibleNavigationLinks {
            NavigationLink.programmatic(isActive: $viewModel.isOriginalRequestHeadersLinkActive, destination:  { NetworkHeadersDetailsView(viewModel: viewModel.requestHeaders) })
            NavigationLink.programmatic(isActive: $viewModel.isResponseHeadersLinkActive, destination:  { NetworkHeadersDetailsView(viewModel: viewModel.responseHeaders) })
        }
    }
}

// MARK: - ViewModel

final class NetworkInspectorTransactionViewModel: ObservableObject {
    @Published var isOriginalRequestHeadersLinkActive = false
    @Published var isResponseHeadersLinkActive = false

    let details: NetworkMetricsDetailsViewModel?
    let timingViewModel: TimingViewModel?

    private let transaction: NetworkLogger.TransactionMetrics

    init(transaction: NetworkLogger.TransactionMetrics, metrics: NetworkLogger.Metrics) {
        self.details = NetworkMetricsDetailsViewModel(metrics: transaction)
        self.timingViewModel = TimingViewModel(transaction: transaction, metrics: metrics)
        self.transaction = transaction
    }

    lazy var requestSummary: KeyValueSectionViewModel = {
        guard let request = transaction.request else {
            return KeyValueSectionViewModel(title: "Request", color: .secondary, items: [])
        }
        return KeyValueSectionViewModel.makeSummary(for: request)
    }()

    lazy var requestParameters = transaction.request.map(KeyValueSectionViewModel.makeParameters)

    lazy var requestHeaders = KeyValueSectionViewModel.makeRequestHeaders(
        for: transaction.request?.headers ?? [:],
        action: { [unowned self] in self.isOriginalRequestHeadersLinkActive = true }
    )

    lazy var responseSummary: KeyValueSectionViewModel = {
        guard let response = transaction.response else {
            return KeyValueSectionViewModel(title: "Response", color: .indigo)
        }
        return KeyValueSectionViewModel.makeSummary(for: response)
    }()

    lazy var responseHeaders = KeyValueSectionViewModel.makeRequestHeaders(
        for: transaction.response?.headers ?? [:],
        action: { [unowned self] in self.isResponseHeadersLinkActive = true }
    )

    lazy var timingSummary = KeyValueSectionViewModel.makeTiming(for: transaction)
}

#if DEBUG
struct NetworkInspectorTransactionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NetworkInspectorTransactionView(viewModel: mockModel)
                .background(Color(UXColor.systemBackground))
                .backport.navigationTitle("Network Load")
        }
        .previewDisplayName("Light")
        .environment(\.colorScheme, .light)
    }
}

private let mockModel = NetworkInspectorTransactionViewModel(
    transaction: mockMetrics.transactions.last!,
    metrics: mockMetrics
)

private let mockMetrics = LoggerStore.preview.entity(for: .login).metrics!

#endif

#endif

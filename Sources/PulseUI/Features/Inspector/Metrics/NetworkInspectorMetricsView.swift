// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(iOS) || os(macOS)

// MARK: - View

struct NetworkInspectorMetricsView: View {
    let viewModel: NetworkInspectorMetricsViewModel
    @State private var isTransctionsListShown = false

    private static let padding: CGFloat = 16

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack {
                TimingView(viewModel: viewModel.timingViewModel)
                    .padding(NetworkInspectorMetricsView.padding)
#if !os(tvOS)
                if let transactions = viewModel.transactions {
                    LargeSectionHeader(title: "Transactions")
                        .padding(.leading, NetworkInspectorMetricsView.padding)
                    NetworkInspectorTransactionsListView(viewModel: transactions)
                        .padding([.leading, .trailing], NetworkInspectorMetricsView.padding)
                }
                if let details = viewModel.details {
                    LargeSectionHeader(title: "Latest Details")
                        .padding(.leading, nil)
                    NetworkInspectorMetricsDetailsView(viewModel: details)
                        .padding([.leading, .bottom, .trailing], NetworkInspectorMetricsView.padding)
                }
#endif
            }
        }
#if os(tvOS)
        .frame(maxWidth: 1200, alignment: .center)
#endif
        .backport.navigationTitle("Metrics")
    }
}

// MARK: - ViewModel

final class NetworkInspectorMetricsViewModel {
    let metrics: NetworkLoggerMetrics
    let timingViewModel: TimingViewModel
#if !os(tvOS)
    let details: NetworkMetricsDetailsViewModel?
    let transactions: NetworkInspectorTransactionsListViewModel?
#endif

    init(metrics: NetworkLoggerMetrics) {
        self.metrics = metrics
        self.timingViewModel = TimingViewModel(metrics: metrics)

#if !os(tvOS)
        self.details = metrics.transactions.first(where: {
            $0.resourceFetchType == URLSessionTaskMetrics.ResourceFetchType.networkLoad.rawValue
        }).map(NetworkMetricsDetailsViewModel.init)
        if !metrics.transactions.isEmpty {
            self.transactions = NetworkInspectorTransactionsListViewModel(metrics: metrics)
        } else {
            self.transactions = nil
        }
#endif
    }
}

// MARK: - Preview

#if DEBUG
struct NetworkInspectorMetricsView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkInspectorMetricsView(viewModel: .init(
            metrics: MockTask.login.metrics
        ))
    }
}
#endif

#endif

// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

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
    let metrics: NetworkLogger.Metrics
    let timingViewModel: TimingViewModel
#if !os(tvOS)
    let transactions: NetworkInspectorTransactionsListViewModel?
#endif

    init(metrics: NetworkLogger.Metrics) {
        self.metrics = metrics
        self.timingViewModel = TimingViewModel(metrics: metrics)

#if !os(tvOS)
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
        NavigationView {
            NetworkInspectorMetricsView(viewModel: .init(
                metrics: LoggerStore.preview.entity(for: .octocat).details!.metrics!
            ))
        }
    }
}
#endif

#endif

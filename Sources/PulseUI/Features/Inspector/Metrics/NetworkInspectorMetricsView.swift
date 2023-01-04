// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#warning("TODO: simplify")

#if os(iOS) || os(macOS)

// MARK: - View

struct NetworkInspectorMetricsView: View {
    let viewModel: NetworkInspectorMetricsViewModel
    @State private var isTransctionsListShown = false

    var body: some View {
        ScrollView {
            TimingView(viewModel: viewModel.timingViewModel)
                .padding()
#if os(macOS)
            if let transactions = viewModel.transactions {
                NetworkInspectorTransactionsListView(viewModel: transactions)
                    .padding(.bottom, 16)
            }
#endif
        }
        .backport.navigationTitle("Metrics")
    }
}

// MARK: - ViewModel

final class NetworkInspectorMetricsViewModel {
    let task: NetworkTaskEntity
    let timingViewModel: TimingViewModel
#if !os(tvOS)
    let transactions: NetworkInspectorTransactionsListViewModel?
#endif

    init?(task: NetworkTaskEntity) {
        guard task.hasMetrics else { return nil }
        self.task = task
        self.timingViewModel = TimingViewModel(task: task)

#if !os(tvOS)
        if !task.transactions.isEmpty {
            self.transactions = NetworkInspectorTransactionsListViewModel(task: task)
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
                task: LoggerStore.preview.entity(for: .octocat)
            )!)
        }
    }
}
#endif

#endif

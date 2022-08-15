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
#if os(macOS)
                        .padding(.bottom, 16)
#endif
                }
#endif
            }
        }
#if os(tvOS)
        .frame(maxWidth: 1200, alignment: .center)
#endif
#if !os(iOS)
        .backport.navigationTitle("Metrics")
#endif
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

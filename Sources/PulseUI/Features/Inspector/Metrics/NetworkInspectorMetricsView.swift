// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

// MARK: - View

struct NetworkInspectorMetricsView: View {
    let viewModel: NetworkInspectorMetricsViewModel

    var body: some View {
#if os(tvOS)
        ForEach(viewModel.transactions) {
            NetworkInspectorTransactionView(viewModel: $0)
        }
#else
        let list = List {
            ForEach(viewModel.transactions) {
                NetworkInspectorTransactionView(viewModel: $0)
            }
        }.backport.navigationTitle("Metrics")
        if #available(iOS 14, *) {
            list.listStyle(.insetGrouped)
        } else {
            list
        }
#endif
    }
}

// MARK: - ViewModel

final class NetworkInspectorMetricsViewModel {
    private(set) lazy var transactions = task.orderedTransactions.map {
        NetworkInspectorTransactionViewModel(transaction: $0, task: task)
    }

    private let task: NetworkTaskEntity

    init?(task: NetworkTaskEntity) {
        guard task.hasMetrics else { return nil }
        self.task = task
    }
}

// MARK: - Preview

#if DEBUG
struct NetworkInspectorMetricsView_Previews: PreviewProvider {
    static var previews: some View {
#if os(macOS)
        NetworkInspectorMetricsView(viewModel: .init(
            task: LoggerStore.preview.entity(for: .createAPI)
        )!)
#else
        NavigationView {
            NetworkInspectorMetricsView(viewModel: .init(
                task: LoggerStore.preview.entity(for: .createAPI)
            )!)
        }
#endif
    }
}
#endif


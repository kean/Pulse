// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

// MARK: - View

struct NetworkInspectorMetricsView: View {
    let viewModel: NetworkInspectorMetricsViewModel

    var body: some View {
        List {
            ForEach(viewModel.transactions) {
                NetworkInspectorTransactionView(viewModel: $0)
            }
        }
        .backport.navigationTitle("Metrics")
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
        NavigationView {
            NetworkInspectorMetricsView(viewModel: .init(
                task: LoggerStore.preview.entity(for: .createAPI)
            )!)
        }
        #if os(tvOS)
        .frame(width: 900)
        #endif
    }
}
#endif


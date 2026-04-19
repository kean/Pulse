// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if !os(watchOS)

import SwiftUI
import Pulse

// MARK: - View

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct NetworkInspectorMetricsView: View {
    let viewModel: NetworkInspectorMetricsViewModel

    var body: some View {
#if os(tvOS)
        ForEach(viewModel.transactions) {
            NetworkInspectorTransactionView(viewModel: $0)
        }
#else
        List {
            ForEach(viewModel.transactions) {
                NetworkInspectorTransactionView(viewModel: $0)
            }
        }
#if os(iOS) || os(visionOS)
        .listStyle(.insetGrouped)
#endif
#if os(macOS)
        .scrollContentBackground(.hidden)
#endif
#if !os(macOS)
        .navigationTitle("Metrics")
#endif
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
@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
#Preview(traits: .fixedLayout(width: 500, height: 800)) {
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
#endif

#endif

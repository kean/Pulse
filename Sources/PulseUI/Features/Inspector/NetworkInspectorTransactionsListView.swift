// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(iOS)

// MARK: - View

struct NetworkInspectorTransactionsListView: View {
    let viewModel: NetworkInspectorTransactionsListViewModel

    var body: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.items) { item in
                NavigationLink(destination: { destination(for: item) }) {
                    ItemView(item: item)
                }
            }
        }
    }

    struct ItemView: View {
        let item: NetworkInspectorTransactionsListViewModel.Item

        var body: some View {
            HStack {
                Text(item.title)
                if let details = item.details {
                    Text(details)
                        .foregroundColor(.secondary)
                }
                Image(systemName: "chevron.right")
                    .foregroundColor(.separator)
                Spacer()
            }
        }
    }

    private func destination(for item: NetworkInspectorTransactionsListViewModel.Item) -> some View {
        NetworkInspectorTransactionView(viewModel: item.viewModel())
            .navigationBarTitle(item.title)
    }
}

// MARK: - ViewModel

final class NetworkInspectorTransactionsListViewModel {
    let items: [Item]

    struct Item: Identifiable {
        let id = UUID()
        let title: String
        let details: String?
        let viewModel: () -> NetworkInspectorTransactionViewModel
    }

    init(metrics: NetworkLoggerMetrics) {
        self.items = metrics.transactions.map { transaction in
            let title: String
            switch URLSessionTaskMetrics.ResourceFetchType(rawValue: transaction.resourceFetchType) ?? .unknown {
            case .networkLoad: title = "Network Load"
            case .localCache: title = "Cache Lookup"
            case .serverPush: title = "Server Push"
            case .unknown: title = "Unknown"
            default: title = "Unknown"
            }
            var details: String?
            if let startDate = transaction.fetchStartDate {
                let endDate = transaction.responseEndDate ?? metrics.taskInterval.end
                details = DurationFormatter.string(from: endDate.timeIntervalSince(startDate))
            }
            return Item(title: title, details: details, viewModel: {
                NetworkInspectorTransactionViewModel(transaction: transaction, metrics: metrics)
            })
        }
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 14.0, *)
struct NetworkInspectorTransactionsListView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                NetworkInspectorTransactionsListView(viewModel: mockModel)
                    .background(Color(UXColor.systemBackground))
            }
            .previewDisplayName("Light")
            .environment(\.colorScheme, .light)

            NavigationView {
                NetworkInspectorTransactionsListView(viewModel: mockModel)
                    .background(Color(UXColor.systemBackground))
                    .previewDisplayName("Dark")
            }
            .environment(\.colorScheme, .dark)
            .previewLayout(.fixed(width: 500, height: 600))
        }
    }
}

private let mockModel = NetworkInspectorTransactionsListViewModel(
    metrics: MockDataTask.login.metrics
)
#endif

#endif

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#warning("TODO: fix this on macOs")

#if os(iOS) || os(macOS) || os(tvOS)

// MARK: - View

struct NetworkInspectorTransactionsListView: View {
    let viewModel: NetworkInspectorTransactionsListViewModel
    @State private var presented: NetworkInspectorTransactionsListViewModel.Item?

    var body: some View {
        ForEach(viewModel.items) { item in
            NavigationLink(destination: destination(for: item)) {
                ItemView(item: item)
            }
        }
    }

    struct ItemView: View {
        let item: NetworkInspectorTransactionsListViewModel.Item

        var body: some View {
            HStack {
                Text(item.title)
                Spacer()
                if let details = item.details {
                    Text(details)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func destination(for item: NetworkInspectorTransactionsListViewModel.Item) -> some View {
        NetworkInspectorTransactionView(viewModel: item.viewModel())
            .backport.navigationTitle(item.title)
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

    init(task: NetworkTaskEntity) {
        self.items = task.transactions.map { transaction in
            let title: String = {
                switch transaction.fetchType {
                case .networkLoad: return "Network Load"
                case .localCache: return "Cache Lookup"
                case .serverPush: return "Server Push"
                case .unknown: return "Unknown"
                default: return "Unknown"
                }
            }()
            var details: String?
            if let startDate = transaction.timing.fetchStartDate,
               let endDate = transaction.timing.responseEndDate ?? task.taskInterval?.end {
                details = DurationFormatter.string(from: endDate.timeIntervalSince(startDate))
            }
            return Item(title: title, details: details, viewModel: {
                NetworkInspectorTransactionViewModel(transaction: transaction, task: task)
            })
        }
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 14, *)
struct NetworkInspectorTransactionsListView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            NetworkInspectorTransactionsListView(viewModel: mockModel)
        }
    }
}

private let mockModel = NetworkInspectorTransactionsListViewModel(
    task: LoggerStore.preview.entity(for: .login)
)
#endif

#endif

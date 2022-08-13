// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS) || os(macOS)

// MARK: - View

struct NetworkInspectorTransactionsListView: View {
    let viewModel: NetworkInspectorTransactionsListViewModel
    @State private var presented: NetworkInspectorTransactionsListViewModel.Item?

    var body: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.items) { item in
                #if os(macOS)
                HStack {
                    Button(action: { presented = item }) {
                        ItemView(item: item)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    Spacer()
                }
                #else
                NavigationLink(destination: { destination(for: item) }) {
                    ItemView(item: item)
                }
                #endif
            }
        }
        #if os(macOS)
        .sheet(item: $presented, content: destination)
         #endif
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
#if os(iOS)
        NetworkInspectorTransactionView(viewModel: item.viewModel())
            .navigationBarTitle(item.title)
#else
        VStack(spacing: 0) {
            HStack {
                Text("\(item.title) Details")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Close") { presented = nil }
                    .keyboardShortcut(.cancelAction)
            }.padding()
            NetworkInspectorTransactionView(viewModel: item.viewModel())
        }
        .navigationTitle(item.title)
        .frame(minWidth: 400, idealWidth: 800, maxWidth: 1000, minHeight: 300, idealHeight: 600)
#endif
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
            let title: String
            switch transaction.fetchType {
            case .networkLoad: title = "Network Load"
            case .localCache: title = "Cache Lookup"
            case .serverPush: title = "Server Push"
            case .unknown: title = "Unknown"
            default: title = "Unknown"
            }
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
@available(iOS 14.0, *)
struct NetworkInspectorTransactionsListView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkInspectorTransactionsListView(viewModel: mockModel)
            .previewLayout(.fixed(width: 320, height: 400))
    }
}

private let mockModel = NetworkInspectorTransactionsListViewModel(
    task: LoggerStore.preview.entity(for: .login)
)
#endif

#endif

// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(iOS) || os(macOS)

// MARK: - View

struct NetworkInspectorTransactionsListView: View {
    let viewModel: NetworkInspectorTransactionsListViewModel

    private static let padding: CGFloat = 16

    var body: some View {
        List {
            ForEach(viewModel.sections) { section in
                Section(header: SectionHeader(title: section.title)) {
                    ForEach(section.items) { item in
                        NavigationLink(destination: { NetworkInspectorTransactionView(viewModel: item.viewModel()) }) {
                            ItemView(item: item)
                        }
                    }
                }
            }
        }
        .navigationBarTitle("Transactions")
    }

    struct SectionHeader: View {
        let title: String

        var body: some View {
            if #available(iOS 14.0, *) {
                text.textCase(nil)
            } else {
                text
            }
        }

        private var text: some View {
            Text(title)
                .font(.subheadline)
                .fontWeight(.regular)
                .lineLimit(2)
                .padding(.bottom, 8)
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
}

// MARK: - ViewModel

final class NetworkInspectorTransactionsListViewModel {
    let sections: [Section]

    struct Section: Identifiable {
        let id = UUID()
        let title: String
        var items: [Item] = []
    }

    struct Item: Identifiable {
        let id = UUID()
        let title: String
        let details: String?
        let viewModel: () -> NetworkInspectorTransactionViewModel
    }

    init(metrics: NetworkLoggerMetrics) {
        var currentURL: URL?
        var sections: [Section] = []

        for transaction in metrics.transactions {
            if transaction.request?.url != currentURL {
                currentURL = transaction.request?.url
                let prefix = transaction.request?.httpMethod.map { $0 + " " } ?? ""
                sections.append(Section(title: prefix + (transaction.request?.url?.absoluteString ?? "Empty URL")))
            }
            let title: String
            switch URLSessionTaskMetrics.ResourceFetchType(rawValue: transaction.resourceFetchType) ?? .unknown {
            case .networkLoad: title = "Network Load"
            case .localCache: title = "Cache Lookup"
            case .serverPush: title = "Server Push"
            case .unknown: title = "Unknown"
            default: title = "Unknown"
            }
            var details: String?
            if let startDate = transaction.fetchStartDate, let endDate = transaction.responseEndDate {
                details = DurationFormatter.string(from: endDate.timeIntervalSince(startDate))
            }
            let item = Item(title: title, details: details, viewModel: { NetworkInspectorTransactionViewModel(transaction: transaction) })

            sections[sections.endIndex - 1].items.append(item)
        }

        self.sections = sections
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

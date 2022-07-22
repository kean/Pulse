// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(iOS) || os(macOS) || os(tvOS)

// MARK: - View

struct NetworkInspectorTransactionView: View {
    @ObservedObject var viewModel: NetworkInspectorTransactionViewModel

    var body: some View {
        ScrollView {
            VStack {
                Section(header: SectionHeader(title: "Request")) {
                    KeyValueSectionView(viewModel: viewModel.requestSummary)
                    if let requestParameters = viewModel.requestParameters {
                        KeyValueSectionView(viewModel: requestParameters)
                    }
                    KeyValueSectionView(viewModel: viewModel.requestHeaders)
                }
                Section(header: SectionHeader(title: "Response")) {
                    KeyValueSectionView(viewModel: viewModel.responseHeaders)
                }
                Section(header: SectionHeader(title: "Details")) {
                    NetworkInspectorMetricsDetailsView(viewModel: viewModel.details)
                        .padding()
                }
            }
            .padding()
        }
    }

    struct SectionHeader: View {
        let title: String

        var body: some View {
            VStack {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                }
                Divider()
            }
        }
    }

    @ViewBuilder
    private var links: some View {
        NavigationLink.programmatic(isActive: $viewModel.isRequestHeadersLinkActive, destination:  { NetworkHeadersDetailsView(viewModel: viewModel.requestHeaders) })
        NavigationLink.programmatic(isActive: $viewModel.isResponseHeadersLinkActive, destination:  { NetworkHeadersDetailsView(viewModel: viewModel.responseHeaders) })
    }
}

// MARK: - ViewModel

final class NetworkInspectorTransactionViewModel: ObservableObject {
    @Published var isRequestHeadersLinkActive = false
    @Published var isResponseHeadersLinkActive = false

    let details: NetworkMetricsDetailsViewModel

    private let transaction: NetworkLoggerTransactionMetrics

    init(transaction: NetworkLoggerTransactionMetrics) {
        self.details = NetworkMetricsDetailsViewModel(metrics: transaction)
        self.transaction = transaction
    }

    lazy var requestSummary: KeyValueSectionViewModel = {
        guard let request = transaction.request else {
            return KeyValueSectionViewModel(title: "Request", color: .secondary, items: [])
        }
        return KeyValueSectionViewModel(
            title: "Request Summary",
            color: .blue,
            items: [
                ("URL", request.url?.absoluteString),
                ("HTTP Method", request.httpMethod)
            ]
        )
    }()

    lazy var requestParameters: KeyValueSectionViewModel? = {
        transaction.request.map(KeyValueSectionViewModel.makeRequestParameters)
    }()

    lazy var requestHeaders: KeyValueSectionViewModel = {
        let items = (transaction.request?.headers ?? [:]).sorted(by: { $0.key < $1.key })
        return KeyValueSectionViewModel(
            title: "Request Headers",
            color: .blue,
            action: ActionViewModel(
                action: { [unowned self] in isRequestHeadersLinkActive = true },
                title: "View Raw"
            ),
            items: items
        )
    }()

    lazy var responseHeaders: KeyValueSectionViewModel = {
        let items = (transaction.response?.headers ?? [:]).sorted(by: { $0.key < $1.key })
        return KeyValueSectionViewModel(
            title: "Response Headers",
            color: .indigo,
            action: ActionViewModel(
                action: { [unowned self] in isResponseHeadersLinkActive = true },
                title: "View Raw"
            ),
            items: items
        )
    }()
}

#if DEBUG
struct NetworkInspectorTransactionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NetworkInspectorTransactionView(viewModel: mockModel)
                .background(Color(UXColor.systemBackground))
                .navigationBarTitle("Network Load")
        }
        .previewDisplayName("Light")
        .environment(\.colorScheme, .light)
    }
}

private let mockModel = NetworkInspectorTransactionViewModel(
    transaction: MockDataTask.login.metrics.transactions.last!
)

#endif

#endif

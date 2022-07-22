// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(iOS)

// MARK: - View

struct NetworkInspectorTransactionView: View {
    @ObservedObject var viewModel: NetworkInspectorTransactionViewModel

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack {
                    if !viewModel.timing.isEmpty {
                        TimingView(viewModel: viewModel.timing, width: geo.size.width - 32)
                    }
                    Section(header: SectionHeader(title: "Request")) {
                        KeyValueSectionView(viewModel: viewModel.requestSummary)
                        KeyValueSectionView(viewModel: viewModel.requestHeaders)
                        if let requestParameters = viewModel.requestParameters {
                            KeyValueSectionView(viewModel: requestParameters)
                        }
                    }
                    Section(header: SectionHeader(title: "Response")) {
                        KeyValueSectionView(viewModel: viewModel.responseSummary)
                        KeyValueSectionView(viewModel: viewModel.responseHeaders)
                    }
                    Section(header: SectionHeader(title: "Details")) {
                        ForEach(viewModel.details.sections, id: \.title) {
                            KeyValueSectionView(viewModel: $0)
                        }
                    }
                    Section(header: SectionHeader(title: "Timing")) {
                        KeyValueSectionView(viewModel: viewModel.timingSummary)
                    }
                }
                .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
            }
        }
        .background(links)
    }

    struct SectionHeader: View {
        let title: String

        var body: some View {
            VStack(spacing: 10) {
                HStack {
                    Text(title)
                        .bold()
                        .font(.title)
                        .padding(.top, 16)
                    Spacer()
                }
                Divider()
            }
            .padding(.bottom, 8)
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
    let timing: [TimingRowSectionViewModel]

    private let transaction: NetworkLoggerTransactionMetrics

    init(transaction: NetworkLoggerTransactionMetrics) {
        self.details = NetworkMetricsDetailsViewModel(metrics: transaction)
        self.timing = TimingRowSectionViewModel.make(transaction: transaction)
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

    lazy var responseSummary: KeyValueSectionViewModel = {
        guard let response = transaction.response else {
            return KeyValueSectionViewModel(title: "Response", color: .indigo, items: [])
        }
        return KeyValueSectionViewModel(title: "Response Summary", color: .indigo, items: [
            ("Status Code", response.statusCode.map { String($0) }),
            ("Content Type", response.contentType),
            ("Expected Content Length", response.expectedContentLength.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) })
        ])
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

    lazy var timingSummary: KeyValueSectionViewModel = {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss.SSS"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.doesRelativeDateFormatting = true

        var startDate: Date?
        var items: [(String, String?)] = []
        func addDate(_ date: Date?, title: String) {
            guard let date = date else { return }
            if items.isEmpty {
                startDate = date
                items.append(("Date", dateFormatter.string(from: date)))
            }
            var value = timeFormatter.string(from: date)
            if let startDate = startDate, startDate != date {
                let duration = date.timeIntervalSince(startDate)
                value += " (+\(DurationFormatter.string(from: duration)))"
            }
            items.append((title, value))
        }
        addDate(transaction.fetchStartDate, title: "Fetch Start")
        addDate(transaction.domainLookupStartDate, title: "Domain Lookup Start")
        addDate(transaction.domainLookupEndDate, title: "Domain Lookup End")
        addDate(transaction.connectStartDate, title: "Connect Start")
        addDate(transaction.secureConnectionStartDate, title: "Secure Connect Start")
        addDate(transaction.secureConnectionEndDate, title: "Secure Connect End")
        addDate(transaction.connectEndDate, title: "Connect End")
        addDate(transaction.requestStartDate, title: "Request Start")
        addDate(transaction.requestEndDate, title: "Request End")
        addDate(transaction.responseStartDate, title: "Response Start")
        addDate(transaction.responseEndDate, title: "Response End")

        return KeyValueSectionViewModel(title: "Timing", color: .orange, items: items)
    }()
}

#if DEBUG
struct NetworkInspectorTransactionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NetworkInspectorTransactionView(viewModel: mockModel)
                .background(Color(UXColor.systemBackground))
#if os(iOS)
                .navigationBarTitle("Network Load")
#endif
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

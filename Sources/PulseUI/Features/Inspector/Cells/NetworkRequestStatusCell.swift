// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

@available(iOS 15, *)
struct NetworkRequestStatusCell: View {
    let viewModel: NetworkRequestStatusCellModel

#if os(watchOS)
    var body: some View {
        HStack(spacing: spacing) {
            Text(viewModel.status.title)
                .lineLimit(3)
                .foregroundColor(viewModel.status.tint)
            Spacer()
            detailsView
        }
        .font(.headline)
        .listRowBackground(Color.clear)
    }

#else
    var body: some View {
        HStack(spacing: spacing) {
            viewModel.status.text
                .lineLimit(1)
            Spacer()
            detailsView
        }
#if os(tvOS)
        .font(.system(size: 38, weight: .bold))
        .padding(.top, 16)
        .padding(.bottom, 16)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
#else
        .font(.headline)
#endif
    }

    #endif

    @ViewBuilder
    private var detailsView: some View {
        if viewModel.isMock {
            MockBadgeView()
        } else {
            viewModel.duration.map(DurationLabel.init)
        }
    }
}

struct NetworkRequestStatusCellModel {
    let status: StatusLabelViewModel
    let isMock: Bool
    fileprivate let duration: DurationViewModel?

    init(task: NetworkTaskEntity, store: LoggerStore) {
        self.status = StatusLabelViewModel(task: task, store: store)
        self.duration = DurationViewModel(task: task)
        self.isMock = task.isMocked
    }

    init(transaction: NetworkTransactionMetricsEntity) {
        status = StatusLabelViewModel(transaction: transaction)
        duration = DurationViewModel(transaction: transaction)
        isMock = false
    }
}

// MARK: - Helpers

private struct DurationLabel: View {
    @ObservedObject var viewModel: DurationViewModel

    var body: some View {
        if let duration = viewModel.duration {
            Text(duration)
                .lineLimit(1)
                .font(.system(.callout, design: .monospaced).monospacedDigit())
                .foregroundColor(.secondary)
        }
    }
}

private final class DurationViewModel: ObservableObject {
    @Published var duration: String?

    private weak var timer: Timer?

    init(task: NetworkTaskEntity) {
        switch task.state {
        case .pending:
            // TODO: Update in sync with the object (creation date is not the same as fetch start date)
//            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
//                self?.refreshPendingDuration(task: task)
//            }
            duration = nil
        case .failure, .success:
            duration = DurationFormatter.string(from: task.duration, isPrecise: false)
        }
    }

    init?(transaction: NetworkTransactionMetricsEntity) {
        guard let duration = transaction.timing.duration else {
            return nil
        }
        self.duration = DurationFormatter.string(from: duration, isPrecise: false)
    }

    private func refreshPendingDuration(task: NetworkTaskEntity) {
        let duration = Date().timeIntervalSince(task.createdAt)
        if duration > 0 {
            self.duration = DurationFormatter.string(from: duration, isPrecise: false)
        }
        if task.state != .pending {
            timer?.invalidate()
        }
    }
}

#if os(tvOS)
private let spacing: CGFloat = 20
#else
private let spacing: CGFloat? = nil
#endif

#if DEBUG
@available(iOS 15, *)
struct NetworkRequestStatusCell_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            List {
                ForEach(MockTask.allEntities, id: \.objectID) { task in
                    NetworkRequestStatusCell(viewModel: .init(task: task, store: .mock))
                }
            }
#if os(macOS)
            .frame(width: 260)
#endif
        }
    }
}
#endif

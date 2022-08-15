// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

#if os(iOS) || os(macOS)

struct NetworkInspectorMetricsTabView: View {
    @ObservedObject var viewModel: NetworkInspectorMetricsTabViewModel

    var body: some View {
        if let viewModel = viewModel.metricsViewModel {
            NetworkInspectorMetricsView(viewModel: viewModel)
        } else if viewModel.isPending {
            SpinnerView(viewModel: viewModel.progress)
        } else {
            PlaceholderView(imageName: "exclamationmark.circle", title: "Unavailable")
        }
    }
}

final class NetworkInspectorMetricsTabViewModel: ObservableObject {
    var isPending: Bool { task.state == .pending }
    private(set) lazy var progress = ProgressViewModel(task: task)

    var metricsViewModel: NetworkInspectorMetricsViewModel? {
        NetworkInspectorMetricsViewModel(task: task)
    }

    private let task: NetworkTaskEntity
    private var cancellable: AnyCancellable?

    init(task: NetworkTaskEntity) {
        self.task = task
        cancellable = task.objectWillChange.sink { [weak self] in self?.refresh() }
    }

    private func refresh() {
        withAnimation { objectWillChange.send() }
    }
}

#if DEBUG
struct NetworkInspectorMetricsTabView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkInspectorMetricsTabView(viewModel: .init(task: LoggerStore.preview.entity(for: .login)))
    }
}
#endif

#endif

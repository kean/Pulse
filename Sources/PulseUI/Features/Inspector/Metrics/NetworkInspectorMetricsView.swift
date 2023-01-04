// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#warning("TODO: simplify")

#if os(iOS) || os(macOS)

// MARK: - View

struct NetworkInspectorMetricsView: View {
    let viewModel: NetworkInspectorMetricsViewModel

    var body: some View {
        ScrollView {
            TimingView(viewModel: viewModel.timingViewModel)
                .padding()
        }
        .backport.navigationTitle("Metrics")
    }
}

// MARK: - ViewModel

final class NetworkInspectorMetricsViewModel {
    let task: NetworkTaskEntity
    let timingViewModel: TimingViewModel

    init?(task: NetworkTaskEntity) {
        guard task.hasMetrics else { return nil }
        self.task = task
        self.timingViewModel = TimingViewModel(task: task)
    }
}

// MARK: - Preview

#if DEBUG
struct NetworkInspectorMetricsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NetworkInspectorMetricsView(viewModel: .init(
                task: LoggerStore.preview.entity(for: .octocat)
            )!)
        }
    }
}
#endif

#endif

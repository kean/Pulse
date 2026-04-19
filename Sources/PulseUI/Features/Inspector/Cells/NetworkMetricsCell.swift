// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if !os(watchOS)

import SwiftUI
import Pulse

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct NetworkMetricsCell: View {
    let task: NetworkTaskEntity

    var body: some View {
        NavigationLink(destination: destinationMetrics) {
            NetworkMenuCell(
                icon: "clock.fill",
                tintColor: .orange,
                title: "Metrics",
                details: ""
            )
        }.disabled(!task.hasMetrics)
    }

    private var destinationMetrics: some View {
        NetworkInspectorMetricsViewModel(task: task).map {
            NetworkInspectorMetricsView(viewModel: $0)
        }
    }
}

#endif

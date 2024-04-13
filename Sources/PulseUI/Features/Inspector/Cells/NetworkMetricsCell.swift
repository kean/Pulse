// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

@available(iOS 15, visionOS 1.0, *)
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

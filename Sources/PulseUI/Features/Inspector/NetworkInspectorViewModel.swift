// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

final class NetworkInspectorViewModel: ObservableObject {
    private(set) var title: String = ""

    let summaryViewModel: NetworkInspectorSummaryViewModel
    let responseViewModel: NetworkInspectorResponseViewModel
    let requestViewModel: NetworkInspectorRequestViewModel
#if !os(watchOS) && !os(tvOS)
    let metricsViewModel: NetworkInspectorMetricsTabViewModel
#endif

#if os(macOS)
    let headersViewModel: NetworkInspectorHeadersTabViewModel
#endif

    // TODO: Make private
    let task: NetworkTaskEntity

    init(task: NetworkTaskEntity) {
        self.task = task

        if let url = task.url.flatMap(URL.init(string:)) {
            self.title = url.lastPathComponent
        }

        self.summaryViewModel = NetworkInspectorSummaryViewModel(task: task)
        self.responseViewModel = NetworkInspectorResponseViewModel(task: task)
        self.requestViewModel = NetworkInspectorRequestViewModel(task: task)
#if !os(watchOS) && !os(tvOS)
        self.metricsViewModel = NetworkInspectorMetricsTabViewModel(task: task)
#endif
#if os(macOS)
        self.headersViewModel = NetworkInspectorHeadersTabViewModel(task: task)
#endif
    }

#if os(iOS) || os(macOS)
    var pin: PinButtonViewModel? {
        task.message.map(PinButtonViewModel.init)
    }

    func prepareForSharing() -> String {
        ConsoleShareService.share(task, output: .plainText)
    }
#endif
}

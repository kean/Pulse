// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#warning("TODO: creat ViewModel that are needed only")
#warning("TODO: populate items from there")

#if os(iOS)

final class NetworkInspectorViewModel: ObservableObject {
    private(set) var title: String = ""

    #warning("TODO: maek private")
    let task: NetworkTaskEntity

    private(set) lazy var _progressViewModel = ProgressViewModel(task: task)

    var tintColor: Color {
        switch task.state {
        case .pending: return .orange
        case .success: return .green
        case .failure: return .red
        }
    }

    var statusImageName: String {
        switch task.state {
        case .pending: return "clock.fill"
        case .success: return "checkmark.circle.fill"
        case .failure: return "exclamationmark.octagon.fill"
        }
    }

    private var cancellable: AnyCancellable?

    init(task: NetworkTaskEntity) {
        self.task = task

        if let url = task.url.flatMap(URL.init(string:)) {
            self.title = "/" + url.lastPathComponent
        }

        cancellable = task.objectWillChange.sink { [weak self] in  self?.refresh()
        }
    }

    private func refresh() {
        withAnimation { objectWillChange.send() }
    }

    var transferViewModel: NetworkInspectorTransferInfoViewModel? {
        guard task.hasMetrics else { return nil }
        return NetworkInspectorTransferInfoViewModel(task: task, taskType: task.type ?? .dataTask)
    }

    var progressViewModel: ProgressViewModel? {
        guard task.state == .pending else { return nil }
        return _progressViewModel
    }

    var pin: PinButtonViewModel? {
        task.message.map(PinButtonViewModel.init)
    }

    func prepareForSharing() -> String {
        ConsoleShareService.share(task, output: .plainText)
    }

    var originalRequestHeadersViewModel: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeRequestHeaders(for: task.originalRequest?.headers ?? [:]) {}
    }

    var currenetRequestHeadersViewModel: KeyValueSectionViewModel {
        KeyValueSectionViewModel.makeRequestHeaders(for: task.currentRequest?.headers ?? [:]) {}
    }
}

#else

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
            self.title = "/" + url.lastPathComponent
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

#endif

// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
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
    let request: LoggerNetworkRequestEntity

    init(request: LoggerNetworkRequestEntity) {
        self.request = request

        if let url = request.url.flatMap(URL.init(string:)) {
            self.title = url.lastPathComponent
        }

        self.summaryViewModel = NetworkInspectorSummaryViewModel(request: request)
        self.responseViewModel = NetworkInspectorResponseViewModel(request: request)
        self.requestViewModel = NetworkInspectorRequestViewModel(request: request)
#if !os(watchOS) && !os(tvOS)
        self.metricsViewModel = NetworkInspectorMetricsTabViewModel(request: request)
#endif
#if os(macOS)
        self.headersViewModel = NetworkInspectorHeadersTabViewModel(request: request)
#endif
    }

#if os(iOS) || os(macOS)
    var pin: PinButtonViewModel? {
        request.message.map(PinButtonViewModel.init)
    }

    func prepareForSharing() -> String {
        ConsoleShareService.share(request, output: .plainText)
    }
#endif
}

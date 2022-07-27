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
#if !os(watchOS)
    let metricsViewModel: NetworkInspectorMetricsTabViewModel
#endif

#if os(macOS)
    let headersViewModel: NetworkInspectorHeadersTabViewModel
#endif

    // TODO: Make private
    let request: LoggerNetworkRequestEntity
    let store: LoggerStore

    init(request: LoggerNetworkRequestEntity, store: LoggerStore) {
        self.request = request
        self.store = store

        if let url = request.url.flatMap(URL.init(string:)) {
            self.title = url.lastPathComponent
        }

        self.summaryViewModel = NetworkInspectorSummaryViewModel(request: request, store: store)
        self.responseViewModel = NetworkInspectorResponseViewModel(request: request, store: store)
        self.requestViewModel = NetworkInspectorRequestViewModel(request: request, store: store)
#if !os(watchOS)
        self.metricsViewModel = NetworkInspectorMetricsTabViewModel(request: request)
#endif
#if os(macOS)
        self.headersViewModel = NetworkInspectorHeadersTabViewModel(request: request)
#endif
    }

#if os(iOS) || os(macOS)
    var pin: PinButtonViewModel? {
        request.message.map {
            PinButtonViewModel(store: store, message: $0)
        }
    }

    func prepareForSharing() -> String {
        ConsoleShareService(store: store).share(request, output: .plainText)
    }
#endif
}

// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

final class NetworkInspectorViewModel: ObservableObject {
    private(set) var title: String = ""
    let request: LoggerNetworkRequestEntity
    private let objectId: NSManagedObjectID
    let store: LoggerStore // TODO: make it private
    @Published private var summary: NetworkLoggerSummary
    private var cancellable: AnyCancellable?

    let summaryViewModel: NetworkInspectorSummaryViewModel
    let responseViewModel: NetworkInspectorResponseViewModel
    let headersViewModel: NetworkInspectorHeadersTabViewModel
    let requestViewModel: NetworkInspectorRequestViewModel
    let metricsViewModel: NetworkInspectorMetricsTabViewModel

    init(request: LoggerNetworkRequestEntity, store: LoggerStore) {
        self.objectId = request.objectID
        self.request = request
        self.store = store
        self.summary = NetworkLoggerSummary(request: request, store: store)

        if let url = request.url.flatMap(URL.init(string:)) {
            self.title = url.lastPathComponent
        }

        self.summaryViewModel = NetworkInspectorSummaryViewModel(request: request, store: store)
        self.responseViewModel = NetworkInspectorResponseViewModel(request: request, store: store)
        self.requestViewModel = NetworkInspectorRequestViewModel(request: request, store: store)
        self.headersViewModel = NetworkInspectorHeadersTabViewModel(request: request)
        self.metricsViewModel = NetworkInspectorMetricsTabViewModel(request: request)

        self.cancellable = request.objectWillChange.sink { [weak self] in
            withAnimation {
                self?.refresh()
            }
        }
    }

    private func refresh() {
        summary = NetworkLoggerSummary(request: request, store: store)
    }

    var pin: PinButtonViewModel? {
        request.message.map {
            PinButtonViewModel(store: store, message: $0)
        }
    }

    // MARK: Sharing

    func prepareForSharing() -> String {
        ConsoleShareService(store: store).share(summary, output: .plainText)
    }
}

#warning("TODO: parse request/respones/metrics lazily")

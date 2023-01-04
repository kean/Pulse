// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#warning("TOOD: use @Published instead of objectWillChange")

final class NetworkInspectorViewModel: ObservableObject {
    let title: String

#warning("TOOD: make private")
    let task: NetworkTaskEntity

    #warning("TODO: explicityl unwrapped?")

    private(set) var statusSectionViewModel: NetworkRequestStatusSectionViewModel?
    private(set) var progressViewModel: ProgressViewModel?

    private(set) var originalRequestHeadersViewModel: NetworkHeadersCellViewModel?
    private(set) var originalRequestCookiesViewModel: NetworkCookiesCellViewModel?

    private(set) var currentRequestHeadersViewModel: NetworkHeadersCellViewModel?
    private(set) var currentRequestCookiesViewModel: NetworkCookiesCellViewModel?

    private(set) var responseHeadersViewModel: NetworkHeadersCellViewModel?
    private(set) var responseCookiesViewModel: NetworkCookiesCellViewModel?

    private var cancellable: AnyCancellable?

    init(task: NetworkTaskEntity) {
        self.task = task

        if let url = task.url.flatMap(URL.init(string:)) {
            self.title = url.lastPathComponent
        } else {
            self.title = "Request"
        }

        self.refresh()
        cancellable = task.objectWillChange.sink { [weak self] in
            self?.refresh()
        }
    }

    private func refresh() {
        let url = URL(string: task.url ?? "")
        let originalRequestHeaders = task.originalRequest?.headers
        let currentRequestHeaders = task.currentRequest?.headers
        let responseHeaders = task.response?.headers

        statusSectionViewModel = NetworkRequestStatusSectionViewModel(task: task)
        progressViewModel = task.state == .pending ? ProgressViewModel(task: task) : nil

        originalRequestHeadersViewModel = NetworkHeadersCellViewModel(title: "Request Headers", headers: originalRequestHeaders)
        originalRequestCookiesViewModel = NetworkCookiesCellViewModel(title: "Request Cookies", headers: originalRequestHeaders, url: url)

        currentRequestHeadersViewModel = NetworkHeadersCellViewModel(title: "Request Headers", headers: currentRequestHeaders)
        currentRequestCookiesViewModel = NetworkCookiesCellViewModel(title: "Request Cookies", headers: currentRequestHeaders, url: url)

        responseHeadersViewModel = NetworkHeadersCellViewModel(title: "Response Headers", headers: responseHeaders)
        responseCookiesViewModel = NetworkCookiesCellViewModel(title: "Response Cookies", headers: responseHeaders, url: url)

        withAnimation { objectWillChange.send() }
    }

#warning("TODO: how does it look if there is no transfer info? (check on all platforms)")

    var transferViewModel: NetworkInspectorTransferInfoViewModel? {
        guard task.hasMetrics else { return nil }
        return NetworkInspectorTransferInfoViewModel(task: task, taskType: task.type ?? .dataTask)
    }

    var pinViewModel: PinButtonViewModel? {
        task.message.map(PinButtonViewModel.init)
    }

    func prepareForSharing() -> String {
#if !os(watchOS) && !os(tvOS)
        return ConsoleShareService.share(task, output: .plainText)
#else
        return "Sharing not supported on watchOS"
#endif
    }
}


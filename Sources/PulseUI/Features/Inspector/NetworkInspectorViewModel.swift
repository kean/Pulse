// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

final class NetworkInspectorViewModel: ObservableObject {
    let title: String
    let task: NetworkTaskEntity

    private(set) var statusSectionViewModel: NetworkRequestStatusSectionViewModel?
    private(set) var progressViewModel: ProgressViewModel?

    private(set) var requestBodyViewModel: NetworkRequestBodyCellViewModel?
    private(set) var originalRequestHeadersViewModel: NetworkHeadersCellViewModel?
    private(set) var originalRequestCookiesViewModel: NetworkCookiesCellViewModel?
    private(set) var currentRequestHeadersViewModel: NetworkHeadersCellViewModel?
    private(set) var currentRequestCookiesViewModel: NetworkCookiesCellViewModel?

    private(set) var responseBodyViewModel: NetworkResponseBodyCellViewModel?
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
            withAnimation { self?.objectWillChange.send() }
        }
    }

    private func refresh() {
        let url = URL(string: task.url ?? "")
        let originalRequestHeaders = task.originalRequest?.headers
        let currentRequestHeaders = task.currentRequest?.headers
        let responseHeaders = task.response?.headers

        statusSectionViewModel = NetworkRequestStatusSectionViewModel(task: task)
        progressViewModel = task.state == .pending ? ProgressViewModel(task: task) : nil

        requestBodyViewModel = NetworkRequestBodyCellViewModel(task: task)
        originalRequestHeadersViewModel = NetworkHeadersCellViewModel(title: "Request Headers", headers: originalRequestHeaders)
        originalRequestCookiesViewModel = NetworkCookiesCellViewModel(title: "Request Cookies", headers: originalRequestHeaders, url: url)
        currentRequestHeadersViewModel = NetworkHeadersCellViewModel(title: "Request Headers", headers: currentRequestHeaders)
        currentRequestCookiesViewModel = NetworkCookiesCellViewModel(title: "Request Cookies", headers: currentRequestHeaders, url: url)

        responseBodyViewModel = NetworkResponseBodyCellViewModel(task: task)
        responseHeadersViewModel = NetworkHeadersCellViewModel(title: "Response Headers", headers: responseHeaders)
        responseCookiesViewModel = NetworkCookiesCellViewModel(title: "Response Cookies", headers: responseHeaders, url: url)
    }

    var transferViewModel: NetworkInspectorTransferInfoViewModel? {
        guard task.hasMetrics else { return nil }
        return NetworkInspectorTransferInfoViewModel(task: task, taskType: task.type ?? .dataTask)
    }

    var pinViewModel: PinButtonViewModel? {
        task.message.map(PinButtonViewModel.init)
    }

    func shareTaskAsHTML() -> URL? {
        ShareService.share(task, as: .html).items.first as? URL
    }
}


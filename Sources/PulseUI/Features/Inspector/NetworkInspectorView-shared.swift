// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

extension NetworkInspectorView {
    @ViewBuilder
    static func makeRequestSection(task: NetworkTaskEntity, isCurrentRequest: Bool) -> some View {
        let url = URL(string: task.url ?? "")
        NetworkRequestBodyCell(viewModel: .init(task: task))
        if isCurrentRequest {
            NetworkHeadersCell(viewModel: .init(title: "Request Headers", headers: task.currentRequest?.headers))
            NetworkCookiesCell(viewModel: .init(title: "Request Cookies", headers: task.currentRequest?.headers, url: url))
        } else {
            NetworkHeadersCell(viewModel: .init(title: "Request Headers", headers: task.originalRequest?.headers))
            NetworkCookiesCell(viewModel: .init(title: "Request Cookies", headers: task.originalRequest?.headers, url: url))
        }
    }

    @ViewBuilder
    static func makeResponseSection(task: NetworkTaskEntity) -> some View {
        let url = URL(string: task.url ?? "")
        NetworkResponseBodyCell(viewModel: .init(task: task))
        NetworkHeadersCell(viewModel: .init(title: "Response Headers", headers: task.response?.headers))
        NetworkCookiesCell(viewModel: .init(title: "Response Cookies", headers: task.response?.headers, url: url))
    }

    @ViewBuilder
    static func makeHeaderView(task: NetworkTaskEntity) -> some View {
        ZStack {
            NetworkInspectorTransferInfoView(viewModel: .init(empty: true))
                .hidden()
                .accessibilityHidden(true)
            if task.hasMetrics {
                NetworkInspectorTransferInfoView(viewModel: .init(task: task))
            } else if task.state == .pending {
                SpinnerView(viewModel: ProgressViewModel(task: task))
            } else {
                // Fallback in case metrics are disabled
                let status = NetworkRequestStatusSectionViewModel(task: task).status 
                Image(systemName: status.imageName)
                    .foregroundColor(status.tintColor)
                    .font(.system(size: 64))
            }
        }
    }
}

struct NetworkInspectorRequestTypePicker: View {
    @Binding var isCurrentRequest: Bool

    var body: some View {
        Picker("Request Type", selection: $isCurrentRequest) {
            Text("Original").tag(false)
            Text("Current").tag(true)
        }
    }
}

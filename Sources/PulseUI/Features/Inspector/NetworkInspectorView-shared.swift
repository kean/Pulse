// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct NetworkInspectorSectionRequest: View {
    let viewModel: NetworkInspectorViewModel
    let isCurrentRequest: Bool

    var body: some View {
        viewModel.requestBodyViewModel.map(NetworkRequestBodyCell.init)
        if isCurrentRequest {
            viewModel.currentRequestHeadersViewModel.map(NetworkHeadersCell.init)
            viewModel.currentRequestCookiesViewModel.map(NetworkCookiesCell.init)
        } else {
            viewModel.originalRequestHeadersViewModel.map(NetworkHeadersCell.init)
            viewModel.originalRequestCookiesViewModel.map(NetworkCookiesCell.init)
        }
    }
}

struct NetworkInspectorSectionResponse: View {
    let viewModel: NetworkInspectorViewModel

    var body: some View {
        viewModel.responseBodyViewModel.map(NetworkResponseBodyCell.init)
        viewModel.responseHeadersViewModel.map(NetworkHeadersCell.init)
        viewModel.responseCookiesViewModel.map(NetworkCookiesCell.init)
    }
}

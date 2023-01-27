// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct NetworkRequestBodyCell: View {
    let viewModel: NetworkRequestBodyCellViewModel

    var body: some View {
        NavigationLink(destination: destination) {
            NetworkMenuCell(
                icon: "arrow.up.circle.fill",
                tintColor: .blue,
                title: "Request Body",
                details: viewModel.details
            )
        }
        .foregroundColor(viewModel.isEnabled ? nil : .secondary)
        .disabled(!viewModel.isEnabled)
    }

    private var destination: some View {
        NetworkInspectorRequestBodyView(viewModel: viewModel.detailsViewModel)
    }
}

struct NetworkRequestBodyCellViewModel {
    let details: String
    let isEnabled: Bool
    let detailsViewModel: NetworkInspectorRequestBodyViewModel

    init(task: NetworkTaskEntity) {
        let size = task.requestBodySize
        self.details = size > 0 ? ByteCountFormatter.string(fromByteCount: size) : "Empty"
        self.isEnabled = size > 0
        self.detailsViewModel = NetworkInspectorRequestBodyViewModel(task: task)
    }
}

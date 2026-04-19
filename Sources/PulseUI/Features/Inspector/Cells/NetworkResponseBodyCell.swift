// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct NetworkResponseBodyCell: View {
    let viewModel: NetworkResponseBodyCellViewModel

    @EnvironmentObject private var environment: ConsoleEnvironment

    var body: some View {
        NavigationLink(destination: destination) {
            NetworkMenuCell(
                icon: "arrow.down.circle.fill",
                tintColor: .indigo,
                title: "Response Body",
                details: viewModel.details
            )
        }
        .foregroundColor(viewModel.isEnabled ? nil : .secondary)
        .disabled(!viewModel.isEnabled)
    }

    private var destination: some View {
        NetworkInspectorResponseBodyView(viewModel: viewModel.detailsViewModel)
            .injecting(environment)
    }
}

struct NetworkResponseBodyCellViewModel {
    let details: String
    let isEnabled: Bool
    let detailsViewModel: NetworkInspectorResponseBodyViewModel

    init(task: NetworkTaskEntity) {
        let size = task.responseBodySize
        self.details = size > 0 ? ByteCountFormatter.string(fromByteCount: size) : "Empty"
        self.isEnabled = size > 0
        self.detailsViewModel = NetworkInspectorResponseBodyViewModel(task: task)
    }
}

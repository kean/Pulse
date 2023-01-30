// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct NetworkInspectorRequestBodyView: View {
    let viewModel: NetworkInspectorRequestBodyViewModel

    var body: some View {
        contents
#if !os(macOS)
            .inlineNavigationTitle("Request Body")
#endif
    }

    @ViewBuilder
    private var contents: some View {
        if let viewModel = viewModel.fileViewModel {
            FileViewer(viewModel: viewModel)
                .onDisappear { self.viewModel.onDisappear() }
        } else if viewModel.task.type == .uploadTask {
            PlaceholderView(imageName: "arrow.up.circle", title: {
                var title = "Uploaded from a File"
                if viewModel.task.requestBodySize > 0 {
                    title = "\(ByteCountFormatter.string(fromByteCount: viewModel.task.requestBodySize))\n\(title)"
                }
                return title
            }())
        } else if viewModel.task.requestBodySize > 0 {
            PlaceholderView(imageName: "exclamationmark.circle", title: "Unavailable", subtitle: "The request body is no longer available")
        } else {
            PlaceholderView(imageName: "nosign", title: "Empty Request")
        }
    }
}

final class NetworkInspectorRequestBodyViewModel {
    private(set) lazy var fileViewModel = data.map { data in
        FileViewerViewModel(
            title: "Request Body",
            context: task.requestFileViewerContext,
            data: { data }
        )
    }

    private var data: Data? {
        guard let data = task.requestBody?.data, !data.isEmpty else { return nil }
        return data
    }

    let task: NetworkTaskEntity

    init(task: NetworkTaskEntity) {
        self.task = task
    }

    func onDisappear() {
        task.requestBody?.reset()
    }
}

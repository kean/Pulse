// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct NetworkInspectorResponseBodyView: View {
    let viewModel: NetworkInspectorResponseBodyViewModel

    var body: some View {
        contents
#if !os(macOS)
            .inlineNavigationTitle("Response Body")
#endif
    }

    @ViewBuilder
    var contents: some View {
        if let viewModel = viewModel.fileViewModel {
            FileViewer(viewModel: viewModel)
                .onDisappear { self.viewModel.onDisappear() }
        } else if viewModel.task.type == .downloadTask {
            PlaceholderView(imageName: "arrow.down.circle", title: {
                var title = "Downloaded to a File"
                if viewModel.task.responseBodySize > 0 {
                    title = "\(ByteCountFormatter.string(fromByteCount: viewModel.task.responseBodySize))\n\(title)"
                }
                return title
            }())
        } else if viewModel.task.responseBodySize > 0 {
            PlaceholderView(imageName: "exclamationmark.circle", title: "Unavailable", subtitle: "The response body was deleted from the store to reduce its size")
        } else {
            PlaceholderView(imageName: "nosign", title: "Empty Response")
        }
    }
}

final class NetworkInspectorResponseBodyViewModel {
    private(set) lazy var fileViewModel = data.map { data in
        FileViewerViewModel(
            title: "Response Body",
            context: task.responseFileViewerContext,
            data: { data }
        )
    }

    private var data: Data? {
        guard let data = task.responseBody?.data, !data.isEmpty else { return nil }
        return data
    }

    let task: NetworkTaskEntity

    init(task: NetworkTaskEntity) {
        self.task = task
    }

    func onDisappear() {
        task.responseBody?.reset()
    }
}

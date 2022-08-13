// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

struct NetworkInspectorResponseView: View {
    @ObservedObject var viewModel: NetworkInspectorResponseViewModel
    let onToggleExpanded: () -> Void

    var body: some View {
        if let viewModel = viewModel.fileViewModel {
            FileViewer(viewModel: viewModel, onToggleExpanded: onToggleExpanded)
                .onDisappear { self.viewModel.onDisappear() }
        } else if viewModel.task.state == .pending {
            SpinnerView(viewModel: viewModel.progress)
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

final class NetworkInspectorResponseViewModel: ObservableObject {
    private(set) lazy var progress = ProgressViewModel(task: task)

    var fileViewModel: FileViewerViewModel? {
        if let viewModel = _fileViewModel {
            return viewModel
        }
        if let responseBody = task.responseBody?.data {
            _fileViewModel = FileViewerViewModel(
                title: "Response",
                context: task.responseFileViewerContext,
                data: { responseBody }
            )
        }
        return _fileViewModel
    }

    private var _fileViewModel: FileViewerViewModel?

    let task: NetworkTaskEntity
    private var cancellable: AnyCancellable?

    init(task: NetworkTaskEntity) {
        self.task = task
        cancellable = task.objectWillChange.sink { [weak self] in self?.refresh() }
    }

    func onDisappear() {
        task.responseBody?.reset()
    }

    private func refresh() {
        withAnimation { objectWillChange.send() }
    }
}

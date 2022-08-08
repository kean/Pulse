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
        } else if viewModel.request.state == .pending {
            SpinnerView(viewModel: viewModel.progress)
        } else if viewModel.request.taskType == .downloadTask {
            PlaceholderView(imageName: "arrow.down.circle", title: {
                var title = "Downloaded to a File"
                if viewModel.request.responseBodySize > 0 {
                    title = "\(ByteCountFormatter.string(fromByteCount: viewModel.request.responseBodySize))\n\(title)"
                }
                return title
            }())
        } else if viewModel.request.responseBodySize > 0 {
            PlaceholderView(imageName: "exclamationmark.circle", title: "Unavailable", subtitle: "The response body was deleted from the store to reduce its size")
        } else {
            PlaceholderView(imageName: "nosign", title: "Empty Response")
        }
    }
}

final class NetworkInspectorResponseViewModel: ObservableObject {
    private(set) lazy var progress = ProgressViewModel(request: request)

    var fileViewModel: FileViewerViewModel? {
        if let viewModel = _fileViewModel {
            return viewModel
        }
        if let responseBody = request.responseBody?.data {
            _fileViewModel = FileViewerViewModel(
                title: "Response",
                context: request.responseFileViewerContext,
                data: { responseBody }
            )
        }
        return _fileViewModel
    }

    private var _fileViewModel: FileViewerViewModel?

    let request: LoggerNetworkRequestEntity
    private var cancellable: AnyCancellable?

    init(request: LoggerNetworkRequestEntity) {
        self.request = request
        cancellable = request.objectWillChange.sink { [weak self] in self?.refresh() }
    }

    func onDisappear() {
        request.responseBody?.reset()
    }

    private func refresh() {
withAnimation { objectWillChange.send() }
    }
}

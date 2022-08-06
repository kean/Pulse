// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore
import Combine

struct NetworkInspectorRequestView: View {
    @ObservedObject var viewModel: NetworkInspectorRequestViewModel
    let onToggleExpanded: () -> Void

    var body: some View {
        if let viewModel = viewModel.fileViewModel {
            FileViewer(viewModel: viewModel, onToggleExpanded: onToggleExpanded)
                .onDisappear { self.viewModel.onDisappear() }
        } else if viewModel.request.state == .pending {
            SpinnerView(viewModel: viewModel.progress)
        } else if viewModel.request.taskType == .uploadTask {
            PlaceholderView(imageName: "arrow.up.circle", title: {
                var title = "Uploaded from a File"
                if viewModel.request.requestBodySize > 0 {
                    title = "\(ByteCountFormatter.string(fromByteCount: viewModel.request.requestBodySize, countStyle: .file))\n\(title)"
                }
                return title
            }())
        } else if viewModel.request.requestBodySize > 0 {
            PlaceholderView(imageName: "exclamationmark.circle", title: "Unavailable", subtitle: "The request body was deleted from the store to reduce its size")
        } else {
            PlaceholderView(imageName: "nosign", title: "Empty Request")
        }
    }
}

final class NetworkInspectorRequestViewModel: ObservableObject {
    private(set) lazy var progress = ProgressViewModel(request: request)
    var fileViewModel: FileViewerViewModel? {
        if let viewModel = _fileViewModel {
            return viewModel
        }
        if let requestBody = request.requestBody?.data {
            _fileViewModel = FileViewerViewModel(
                title: "Request",
                context: request.requestFileViewerContext,
                data: { requestBody }
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
        request.requestBody?.reset()
    }

    private func refresh() {
withAnimation { objectWillChange.send() }
    }
}

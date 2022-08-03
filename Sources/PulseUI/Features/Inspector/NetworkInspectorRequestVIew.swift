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
        } else if viewModel.request.requestBodyKey != nil {
            PlaceholderView(imageName: "exclamationmark.circle", title: "Unavailable", messages: "The request body was deleted from the store to reduce its size")
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
        if let requestBodyKey = request.requestBodyKey,
           let requestBody = store.getData(forKey: requestBodyKey),
           !requestBody.isEmpty {
            _fileViewModel = FileViewerViewModel(
                title: "Request",
                context: details.requestFileViewerContext,
                data: { requestBody }
            )
        }
        return _fileViewModel
    }

    private var _fileViewModel: FileViewerViewModel?

    let request: LoggerNetworkRequestEntity
    private var details: DecodedNetworkRequestDetailsEntity
    private let store: LoggerStore
    private var cancellable: AnyCancellable?

    init(request: LoggerNetworkRequestEntity, store: LoggerStore) {
        self.request = request
        self.details = DecodedNetworkRequestDetailsEntity(request: request)
        self.store = store

        cancellable = request.objectWillChange.sink { [weak self] in self?.refresh() }
    }

    private func refresh() {
        withAnimation {
            objectWillChange.send()
        }
    }
}

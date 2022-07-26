// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore
import Combine

struct NetworkInspectorResponseView: View {
    @ObservedObject var viewModel: NetworkInspectorResponseViewModel
    let onToggleExpanded: () -> Void

    var body: some View {
        if let viewModel = viewModel.fileViewModel {
            FileViewer(viewModel: viewModel, onToggleExpanded: onToggleExpanded)
        } else if viewModel.request.state == .pending {
            SpinnerView(viewModel: viewModel.progress)
        } else if viewModel.request.responseBodyKey != nil {
            PlaceholderView(imageName: "exclamationmark.circle", title: "Unavailable")
        } else if viewModel.request.taskType == .downloadTask {
            PlaceholderView(imageName: "arrow.down.circle", title: {
                var title = "Downloaded to a File"
                if viewModel.request.responseBodySize > 0 {
                    title = "\(ByteCountFormatter.string(fromByteCount: viewModel.request.responseBodySize, countStyle: .file))\n\(title)"
                }
                return title
            }())
        } else {
            PlaceholderView(imageName: "nosign", title: "Empty Response")
        }
    }
}

final class NetworkInspectorResponseViewModel: ObservableObject {
    private(set) lazy var progress = ProgressViewModel(request: request)
    private(set) var fileViewModel: FileViewerViewModel?

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
        if let responesBodyKey = request.responseBodyKey,
           let responseBody = store.getData(forKey: responesBodyKey),
           !responseBody.isEmpty {
            fileViewModel = FileViewerViewModel(title: "Response", data: { responseBody })
        }
        withAnimation {
            objectWillChange.send()
        }
    }
}

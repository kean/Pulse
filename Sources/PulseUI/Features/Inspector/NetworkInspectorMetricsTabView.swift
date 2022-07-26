// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore
import Combine

#if os(iOS) || os(macOS) || os(tvOS)

struct NetworkInspectorMetricsTabView: View {
    @ObservedObject var viewModel: NetworkInspectorMetricsTabViewModel

    var body: some View {
        if let viewModel = viewModel.metricsViewModel {
            NetworkInspectorMetricsView(viewModel: viewModel)
        } else if viewModel.isPending {
            SpinnerView(viewModel: viewModel.progress)
        } else {
            PlaceholderView(imageName: "exclamationmark.circle", title: "Unavailable")
        }
    }
}

final class NetworkInspectorMetricsTabViewModel: ObservableObject {
    var isPending: Bool { request.state == .pending }
    private(set) lazy var progress = ProgressViewModel(request: request)

    var metricsViewModel: NetworkInspectorMetricsViewModel?{
        details.metrics.map(NetworkInspectorMetricsViewModel.init)
    }

    private let request: LoggerNetworkRequestEntity
    private var details: DecodedNetworkRequestDetailsEntity
    private var cancellable: AnyCancellable?

    init(request: LoggerNetworkRequestEntity) {
        self.request = request
        self.details = DecodedNetworkRequestDetailsEntity(request: request)

        cancellable = request.objectWillChange.sink { [weak self] in self?.refresh() }
    }

    private func refresh() {
        self.details = DecodedNetworkRequestDetailsEntity(request: request)
        withAnimation {
            objectWillChange.send()
        }
    }
}

#endif

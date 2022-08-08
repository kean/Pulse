// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

#if os(iOS) || os(macOS)

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
        request.details?.metrics.map(NetworkInspectorMetricsViewModel.init)
    }

    private let request: LoggerNetworkRequestEntity
    private var cancellable: AnyCancellable?

    init(request: LoggerNetworkRequestEntity) {
        self.request = request
        cancellable = request.objectWillChange.sink { [weak self] in self?.refresh() }
    }

    private func refresh() {
withAnimation { objectWillChange.send() }
    }
}

#if DEBUG
struct NetworkInspectorMetricsTabView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkInspectorMetricsTabView(viewModel: .init(request: LoggerStore.preview.entity(for: .login)))
    }
}
#endif

#endif

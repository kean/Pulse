// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore
import Combine

#if os(macOS) || os(iOS)

struct NetworkInspectorHeadersTabView: View {
    @ObservedObject var viewModel: NetworkInspectorHeadersTabViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                NetworkInspectorHeadersView(viewModel: viewModel.headersViewModel)
                if viewModel.isPending {
                    SpinnerView(viewModel: viewModel.progress)
                        .frame(height: 120)
                }
                Spacer()
            }
        }
    }
}

final class NetworkInspectorHeadersTabViewModel: ObservableObject {
    var isPending: Bool { request.state == .pending }
    private(set) lazy var progress = ProgressViewModel(request: request)

    var headersViewModel: NetworkInspectorHeaderViewModel {
        NetworkInspectorHeaderViewModel(details: details)
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

#if DEBUG
struct NetworkInspectorHeadersTabView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkInspectorHeadersTabView(viewModel: .init(request: LoggerStore.preview.makeEntity(for: .login)))
    }
}
#endif

#endif

// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
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
    var isPending: Bool { task.state == .pending }
    private(set) lazy var progress = ProgressViewModel(task: task)

    var headersViewModel: NetworkInspectorHeaderViewModel {
        NetworkInspectorHeaderViewModel(task: task)
    }

    private let task: NetworkTaskEntity
    private var cancellable: AnyCancellable?

    init(task: NetworkTaskEntity) {
        self.task = task
        cancellable = task.objectWillChange.sink { [weak self] in self?.refresh() }
    }

    private func refresh() {
        withAnimation { objectWillChange.send() }
    }
}

#if DEBUG
struct NetworkInspectorHeadersTabView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkInspectorHeadersTabView(viewModel: .init(task: LoggerStore.preview.entity(for: .login)))
    }
}
#endif

#endif

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

struct ShareEntitiesView: View {
    @StateObject private var viewModel = ShareEntitiesViewModel()
    private let entities: [NSManagedObject]
    private let store: LoggerStore
    private let output: ShareOutput
    private let completion: (ShareItems?) -> Void

    init(entities: [NSManagedObject], store: LoggerStore, output: ShareOutput, completion: @escaping (ShareItems?) -> Void) {
        self.entities = entities
        self.store = store
        self.output = output
        self.completion = completion
    }

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(viewModel.title)
            Spacer()
            if viewModel.isProcessing {
                Button("Cancel") {
                    viewModel.cancel()
                }
            }
        }
        .padding()
        .onAppear {
            viewModel.prepare(entities: entities, store: store, output: output, completion: completion)
        }
    }
}

private final class ShareEntitiesViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var progress: String?
    @Published var isProcessing = true

    // TODO: use as binding
    @Published var shareItem: ShareItems?

    private var isStarted = false
    private var task: ShareStoreTask?
    private var cancellables: [AnyCancellable] = []

    init() {}

    func prepare(entities: [NSManagedObject], store: LoggerStore, output: ShareOutput, completion: @escaping (ShareItems?) -> Void) {
        guard !isStarted else { return }
        isStarted = true

        let task = ShareStoreTask(entities: entities, store: store, output: output, completion: completion)
        task.$stage.sink { [weak self] in
            guard let self = self else { return }
            switch $0 {
            case .preparing:
                self.title = "Preparing Logs..."
            case .rendering:
                self.progress = nil
                self.title = "Generating \(output.title)..."
            case .completed:
                break
            }
        }.store(in: &cancellables)
        task.start()
        self.task = task
    }

    #warning("TODO: implenet cancellation")
    func cancel() {
        self.task?.cancel()
    }
}

#if DEBUG
struct ShareEntitiesView_Previews: PreviewProvider {
    static var previews: some View {
#if os(iOS)
        ShareEntitiesView(entities: try! LoggerStore.mock.allMessages(), store: .mock, output: .html) { _ in }
#else
        ShareEntitiesView(entities: try! LoggerStore.mock.allMessages(), store: .mock, output: .html) { _ in }
            .frame(width: 300, height: 500)
#endif
    }
}
#endif

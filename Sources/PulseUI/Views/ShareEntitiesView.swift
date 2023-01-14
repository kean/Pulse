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
            ZStack {
                ProgressView()
                    .opacity(viewModel.isProcessing ? 1 : 0)
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .opacity(viewModel.isProcessing ? 0 : 1)
            }
            Text(viewModel.title)
            if let progress = viewModel.progress {
                Text(progress)
                    .backport.monospacedDigit()
                    .foregroundColor(.secondary)
            }
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

    private var task: ShareStoreTask?
    private var cancellables: [AnyCancellable] = []

    init() {}

    func prepare(entities: [NSManagedObject], store: LoggerStore, output: ShareOutput, completion: @escaping (ShareItems?) -> Void) {
        let task = ShareStoreTask(entities: entities, store: store, output: output, completion: completion)
        task.$stage.sink { [weak self] in
            guard let self = self else { return }
            switch $0 {
            case .preparing:
                self.title = "Preparing messages..."
            case .rendering:
                self.progress = nil
                self.title = "Generating \(output.title)..."
            case .completed:
                self.isProcessing = false
                self.title = "Completed"
            }
        }.store(in: &cancellables)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { [weak self] in
            guard let self = self else { return }
            task.$progress.sink { [weak self] in
                self?.progress = "\(Int($0 * 100))%"
            }.store(in: &self.cancellables)
        }
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

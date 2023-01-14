// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

struct ShareEntitiesView: View {
    @StateObject private var viewModel = ShareEntitiesViewModel()
    let entities: [NSManagedObject]
    let store: LoggerStore
    let output: ShareOutput

    @Binding var isPresented: Bool // presentationMode is buggy

    var body: some View {
        HStack {
            ProgressView(viewModel.title, value: viewModel.progress)
                .progressViewStyle(.linear)
                .padding()
        }
        .onAppear { viewModel.prepare(entities: entities, store: store, output: output) }
    }
}

private final class ShareEntitiesViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var progress: Float = 0

    // TODO: use as binding
    @Published var shareItem: ShareItems?

    private var task: ShareStoreTask?
    private var cancellables: [AnyCancellable] = []

    init() {

    }

    func prepare(entities: [NSManagedObject], store: LoggerStore, output: ShareOutput) {
        let task = ShareStoreTask(entities: entities, store: store, output: output)
        task.$title.sink { [weak self] in
            self?.title = $0
        }.store(in: &cancellables)
        task.$progress.sink { [weak self] in
            self?.progress = $0
        }.store(in: &cancellables)
        task.start()
        self.task = task
    }
}

#if DEBUG
struct ShareEntitiesView_Previews: PreviewProvider {
    static var previews: some View {
#if os(iOS)
        ShareEntitiesView(entities: try! LoggerStore.mock.allMessages(), store: .mock, output: .html, isPresented: .constant(true))
#else
        ShareEntitiesView(entities: try! LoggerStore.mock.allMessages(), store: .mock, output: .html, isPresented: .constant(true))
            .frame(width: 300, height: 500)
#endif
    }
}
#endif

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
    let output: ShareOutput

    @Binding var isPresented: Bool // presentationMode is buggy

    var body: some View {
        HStack {
            ProgressView("Preparing for Sharing...", value: 0.5)
                .progressViewStyle(.linear)
                .padding()
        }
        .onAppear { viewModel.prepare(entities: entities, output: output) }
    }
}

private final class ShareEntitiesViewModel: ObservableObject {
    @Published var progress: Float = 0

// TODO: use as binding
    @Published var shareItem: ShareItems?

    init() {

    }

    func prepare(entities: [NSManagedObject], output: ShareOutput) {
        //  
    }
}

#if DEBUG
struct ShareEntitiesView_Previews: PreviewProvider {
    static var previews: some View {
#if os(iOS)
        ShareEntitiesView(entities: try! LoggerStore.mock.allMessages(), output: .html, isPresented: .constant(true))
#else
        ShareEntitiesView(entities: try! LoggerStore.mock.allMessages(), output: .html, isPresented: .constant(true))
            .frame(width: 300, height: 500)
#endif
    }
}
#endif

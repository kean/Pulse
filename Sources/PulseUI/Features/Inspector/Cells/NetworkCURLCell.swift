// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct NetworkCURLCell: View {
    let task: NetworkTaskEntity

    var body: some View {
        NavigationLink(destination: destination) {
            NetworkMenuCell(
                icon: "terminal.fill",
                tintColor: .secondary,
                title: "cURL Representation",
                details: ""
            )
        }
    }

    private var destination: some View {
        let curl = task.cURLDescription()
        let string = TextRenderer().render(curl, style: .monospaced)
        return RichTextView(viewModel: .init(string: string))
            .linkDetectionEnabled(false)
            .backport.navigationTitle("cURL Representation")
    }
}

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS)

struct ConsoleShareButton: View {
    let viewModel: ConsoleViewModel

    @State private var selectedShareOutput: ShareOutput?

    var body: some View {
        if let _ = selectedShareOutput {
            ProgressView()
                .frame(width: 27, height: 27)
        } else {
            Menu(content: {
                Button(action: { share(as: .plainText) }) {
                    Label("Share as Text", systemImage: "square.and.arrow.up")
                }
                Button(action: { share(as: .html) }) {
                    Label("Share as HTML", systemImage: "square.and.arrow.up")
                }
            }, label: {
                Image(systemName: "square.and.arrow.up")
            })
            .disabled(selectedShareOutput != nil)
        }
    }

    private func share(as output: ShareOutput) {
        selectedShareOutput = output
        viewModel.prepareForSharing(as: output) { item in
            selectedShareOutput = nil
            viewModel.router.shareItems = item
        }
    }
}

#endif

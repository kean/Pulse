// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#warning("TODO: remove these")

#if DEBUG

struct RendererPreviews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            if #available(iOS 15, *) {
                ScrollView {
                    // This doesn't provide a complete view, but it's better than nothing
                    Text(try! AttributedString(
                        markdown: Render.asMarkdown(task: task).data(using: .utf8)!,
                        options: .init(
                            interpretedSyntax: .inlineOnlyPreservingWhitespace
                        )
                    )).padding()
                }.previewDisplayName("Markdown")
            }

            RichTextView(viewModel: .init(string: Render.asMarkdown(task: task)))
                .previewDisplayName("Markdown (Raw)")

            RichTextView(viewModel: .init(string: Render.asPlainText(task: task)))
                .previewDisplayName("Plain Text")

            WebView(data: Render.asHTML(task: task).data(using: .utf8)!, contentType: "application/html")
                .previewDisplayName("HTML")
        }
    }
}

private let task = LoggerStore.preview.entity(for: .login)

#endif

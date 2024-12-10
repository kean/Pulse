// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(watchOS) || os(macOS)
struct RichTextView: View {
    let viewModel: RichTextViewModel

    var body: some View {
        ScrollView {
            if let string = viewModel.attributedString {
                Text(string)
            } else {
                Text(viewModel.text)
            }
        }
#if os(watchOS)
        .toolbar {
            if #available(watchOS 9, *) {
                ShareLink(item: viewModel.text)
            }
        }
#endif
    }
}
#endif

final class RichTextViewModel: ObservableObject {
    let text: String
    let attributedString: AttributedString?

    var isLinkDetectionEnabled = true
    var isEmpty: Bool { text.isEmpty }

    init(string: String) {
        self.text = string
        self.attributedString = nil
    }

    init(string: NSAttributedString, contentType: NetworkLogger.ContentType? = nil) {
#if os(macOS)
        self.attributedString = try? AttributedString(string, including: \.appKit)
#else
        self.attributedString = try? AttributedString(string, including: \.uiKit)
#endif
        self.text = string.string
    }
}

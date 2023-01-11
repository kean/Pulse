// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(watchOS) || os(tvOS)

struct RichTextView: View {
    let viewModel: RichTextViewModel

    var body: some View {
        ScrollView {
            if #available(tvOS 15.0, *), let string = viewModel.attributedString {
                Text(string)
            } else {
                Text(viewModel.text)
            }
        }
#if os(watchOS)
        .toolbar {
            if #available(watchOS 9.0, *) {
                ShareLink(item: viewModel.text)
            }
        }
#endif
    }
}

final class RichTextViewModel: ObservableObject {
    let text: String

    @available(tvOS 15.0, *)
    var attributedString: AttributedString? {
        _attributedString as? AttributedString
    }

    private var _attributedString: Any?

    var isLinkDetectionEnabled = true

    var isEmpty: Bool { text.isEmpty }

    init(string: String) {
        self.text = string
    }

    init(string: NSAttributedString, contentType: NetworkLogger.ContentType? = nil) {
        if #available(tvOS 15.0, *) {
            self._attributedString = try? AttributedString(string, including: \.uiKit)
        }
        self.text = string.string
    }
}

#endif

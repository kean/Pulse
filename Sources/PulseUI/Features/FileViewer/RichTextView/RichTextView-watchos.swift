// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(watchOS) || os(macOS)

public struct RichTextView: View {
    let viewModel: RichTextViewModel

    public init(viewModel: RichTextViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
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

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

// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if !PULSE_STANDALONE_APP

struct Components {
    @available(iOS 15, macOS 13, visionOS 1.0, *)
    static func makeSessionPicker(selection: Binding<Set<UUID>>) -> some View {
        SessionPickerView(selection: selection)
    }

    static func makeRichTextView(string: NSAttributedString) -> some View {
        RichTextView(viewModel: .init(string: string))
    }
}

#endif

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleSearchToggleCell: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
#if os(macOS)
        HStack {
            Toggle(title, isOn: $isOn)
            Spacer()
        }
#else
        Toggle(title, isOn: $isOn)
#endif
    }
}

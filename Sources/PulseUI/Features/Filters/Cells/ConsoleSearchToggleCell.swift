// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

package struct ConsoleSearchToggleCell: View {
    package let title: String
    @Binding package var isOn: Bool

    package init(title: String, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }

    package var body: some View {
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

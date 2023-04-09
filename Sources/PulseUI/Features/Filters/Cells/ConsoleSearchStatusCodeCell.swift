// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import Pulse

struct ConsoleSearchStatusCodeCell: View {
    @Binding var selection: ValuesRange<String>

    var body: some View {
        HStack {
            Text("Status Code").lineLimit(1)
            Spacer()
            RangePicker(range: $selection)
        }
    }
}

#endif

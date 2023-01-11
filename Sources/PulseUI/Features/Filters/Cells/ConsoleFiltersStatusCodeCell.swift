// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleFiltersStatusCodeCell: View {
    @Binding var selection: ValuesRange<String>

    var body: some View {
        HStack {
            Text("Status Code")
            Spacer()
            RangePicker(range: $selection)
        }
    }
}

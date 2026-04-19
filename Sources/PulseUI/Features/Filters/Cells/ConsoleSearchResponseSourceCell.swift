// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleSearchResponseSourceCell: View {
    @Binding var selection: ConsoleFilters.Networking.Source

    var body: some View {
        Picker("Response Source", selection: $selection) {
            ForEach(ConsoleFilters.Networking.Source.allCases, id: \.self) {
                Text($0.title).tag($0)
            }
        }
    }
}

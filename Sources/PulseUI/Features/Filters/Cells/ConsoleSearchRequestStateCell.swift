// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleSearchRequestStateCell: View {
    @Binding var selection: ConsoleFilters.Networking.RequestState

    var body: some View {
        Picker("Request State", selection: $selection) {
            ForEach(ConsoleFilters.Networking.RequestState.allCases, id: \.self) {
                Text($0.title).tag($0)
            }
        }
    }
}

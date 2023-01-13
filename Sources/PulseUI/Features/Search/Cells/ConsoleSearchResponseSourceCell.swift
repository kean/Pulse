// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleSearchResponseSourceCell: View {
    @Binding var selection: ConsoleSearchCriteria.Networking.Source

    var body: some View {
        Picker("Response Source", selection: $selection) {
            ForEach(ConsoleSearchCriteria.Networking.Source.allCases, id: \.self) {
                Text($0.title).tag($0)
            }
        }
    }
}

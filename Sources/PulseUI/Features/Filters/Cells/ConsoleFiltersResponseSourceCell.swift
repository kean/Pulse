// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleFiltersResponseSourceCell: View {
    @Binding var selection: ConsoleNetworkSearchCriteria.NetworkingFilter.Source

    var body: some View {
        Picker("Response Source", selection: $selection) {
            ForEach(ConsoleNetworkSearchCriteria.NetworkingFilter.Source.allCases, id: \.self) {
                Text($0.title).tag($0)
            }
        }
    }
}

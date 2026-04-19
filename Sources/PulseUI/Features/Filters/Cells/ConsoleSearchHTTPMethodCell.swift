// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleSearchHTTPMethodCell: View {
    @Binding var selection: ConsoleFilters.Request.HTTPMethodFilter

    var body: some View {
        Picker("HTTP Method", selection: $selection) {
            Text("Any").tag(ConsoleFilters.Request.HTTPMethodFilter.any)
            ForEach(HTTPMethod.allCases, id: \.self) {
                Text($0.rawValue).tag(ConsoleFilters.Request.HTTPMethodFilter.some($0))
            }
        }
    }
}

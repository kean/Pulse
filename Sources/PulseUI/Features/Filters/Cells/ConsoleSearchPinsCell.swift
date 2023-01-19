// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleSearchPinsCell: View {
    @Binding var selection: ConsoleSearchCriteria.General
    let removeAll: () -> Void

    var body: some View {
#if os(macOS)
        HStack {
            ConsoleSearchToggleCell(title: "Only Pinned", isOn: $selection.inOnlyPins)
            Spacer()
            Button.destructive(action: removeAll) {
                Text("Remove Pins")
            }
        }
#else
        ConsoleSearchToggleCell(title: "Only Pinned", isOn: $selection.inOnlyPins)
        Button.destructive(action: removeAll) {
            Text("Remove Pins")
        }
#endif
    }
}

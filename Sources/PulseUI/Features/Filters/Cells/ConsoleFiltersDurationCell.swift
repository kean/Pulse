// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleFiltersDurationCell: View {
    @Binding var selection: ConsoleFilters.Duration

    var body: some View {
        HStack {
            Text("Duration")
            Spacer()
            FilterPickerMenu(title: selection.unit.title, width: 50) {
                Picker("Unit", selection: $selection.unit) {
                    ForEach(ConsoleFilters.Duration.Unit.allCases) {
                        Text($0.title).tag($0)
                    }
                }
                .labelsHidden()
            }
            RangePicker(range: $selection.range)
        }
    }
}

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleSearchDurationCell: View {
    @Binding var selection: ConsoleSearchCriteria.Duration

    var body: some View {
        HStack {
            Text("Duration")
            Spacer()
            ConsoleSearchInlinePickerMenu(title: selection.unit.title, width: 50) {
                Picker("Unit", selection: $selection.unit) {
                    ForEach(ConsoleSearchCriteria.Duration.Unit.allCases) {
                        Text($0.title).tag($0)
                    }
                }
                .labelsHidden()
            }
            RangePicker(range: $selection.range)
        }
    }
}

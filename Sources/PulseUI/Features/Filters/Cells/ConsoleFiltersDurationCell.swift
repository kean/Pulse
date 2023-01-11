// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleFiltersDurationCell: View {
    @Binding var duration: ConsoleNetworkSearchCriteria.DurationFilter

    var body: some View {
        HStack {
            Text("Duration")
            Spacer()
            FilterPickerMenu(title: duration.unit.title, width: 50) {
                Picker("Unit", selection: $duration.unit) {
                    ForEach(ConsoleNetworkSearchCriteria.DurationFilter.Unit.allCases) {
                        Text($0.title).tag($0)
                    }
                }
                .labelsHidden()
            }
            RangePicker(range: $duration.range)
        }
    }
}

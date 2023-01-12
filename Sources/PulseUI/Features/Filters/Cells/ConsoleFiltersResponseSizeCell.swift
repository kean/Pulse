// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleFiltersResponseSizeCell: View {
    @Binding var selection: ConsoleFilters.ResponseSize

    var body: some View {
        HStack {
            Text("Size")
            Spacer()
            FilterPickerMenu(title: selection.unit.title, width: 50) {
                Picker("Unit", selection: $selection.unit) {
                    ForEach(ConsoleFilters.ResponseSize.MeasurementUnit.allCases) {
                        Text($0.title).tag($0)
                    }
                }
                .labelsHidden()
            }
            RangePicker(range: $selection.range)
        }
    }
}

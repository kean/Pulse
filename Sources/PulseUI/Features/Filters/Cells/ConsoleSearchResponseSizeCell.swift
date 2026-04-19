// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleSearchResponseSizeCell: View {
    @Binding var selection: ConsoleFilters.ResponseSize

    var body: some View {
        HStack(spacing: 0) {
            Text("Body Size").lineLimit(1)
            Spacer(minLength: 16)
            Picker("Unit", selection: $selection.unit) {
                ForEach(ConsoleFilters.ResponseSize.MeasurementUnit.allCases) {
                    Text($0.title).tag($0)
                }
            }
            .labelsHidden()
            .padding(.trailing, 12)

            RangePicker(range: $selection.range)
        }
        .frame(height: 18) // Ensure cells have consistent height
    }
}

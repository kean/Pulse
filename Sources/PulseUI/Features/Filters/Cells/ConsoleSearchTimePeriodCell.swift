// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import SwiftUI
import Pulse
import PulseComponents

struct ConsoleSearchTimePeriodCell: View {
    @Binding var selection: ConsoleFilers.Dates

    var body: some View {
        DateRangePicker(title: "Start", date: $selection.startDate)
        DateRangePicker(title: "End", date: $selection.endDate)
        quickFilters
    }

    @ViewBuilder
    private var quickFilters: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Quick Filters")
                .lineLimit(1)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Recent") { selection = .recent }
            Button("Today") { selection = .today }
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
        .foregroundColor(.accentColor)
    }
}

#endif

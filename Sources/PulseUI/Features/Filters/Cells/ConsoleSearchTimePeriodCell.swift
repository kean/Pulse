// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import SwiftUI
import Pulse

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct ConsoleSearchTimePeriodCell: View {
    @Binding var selection: ConsoleFilters.Dates

    var body: some View {
        DateRangePicker(title: "Start", date: $selection.startDate)
        VStack(spacing: 16) {
            DateRangePicker(title: "End", date: $selection.endDate)
            quickFilters
        }
    }

    private var quickFilters: some View {
        SuggestionPills {
            SuggestionPill("30 min") { selection = .last30Minutes }
            SuggestionPill("1 hour") { selection = .lastHour }
            SuggestionPill("Today") { selection = .today }
            SuggestionPill("Yesterday") { selection = .yesterday }
        }
    }
}

#endif

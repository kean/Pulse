// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleSearchTimePeriodCell: View {
    @Binding var selection: ConsoleSearchCriteria.Dates
#if os(tvOS) || os(watchOS)
    @State private var quickFilter: ConsoleDatesQuickFilter = .session
#endif

    var body: some View {
#if os(iOS) || os(macOS)
        DateRangePicker(title: "Start", date: $selection.startDate)
        DateRangePicker(title: "End", date: $selection.endDate)
        quickFilters
#endif

#if os(tvOS) || os(watchOS)
        Picker("Date Range", selection: $quickFilter) {
            ForEach(ConsoleDatesQuickFilter.allCases, id: \.self) {
                Text($0.title).tag($0)
            }
        }
        .onChange(of: quickFilter) {
            if let filter = $0.makeDateFilter() {
                selection = filter
            }
        }
#endif
    }

    @ViewBuilder
    private var quickFilters: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Quick Filters")
                .lineLimit(1)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Session") { selection = .session }
            Button("Recent") { selection = .recent }
            Button("Today") { selection = .today }
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
        .foregroundColor(.accentColor)
    }
}

#if os(tvOS) || os(watchOS)
private enum ConsoleDatesQuickFilter: String, Hashable, CaseIterable {
    case session
    case recent
    case today
    case all

    var title: String { rawValue.capitalized }

    func makeDateFilter() -> ConsoleSearchCriteria.Dates? {
        switch self {
        case .session: return .session
        case .recent: return .recent
        case .today: return .today
        case .all: return nil
        }
    }
}
#endif

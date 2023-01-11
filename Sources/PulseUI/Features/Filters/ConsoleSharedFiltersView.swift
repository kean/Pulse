// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleSharedFiltersView: View {
    @ObservedObject var viewModel: ConsoleSharedSearchCriteriaViewModel

    var body: some View {
        sectionTimePeriod
        sectionFilters
    }

    private var sectionTimePeriod: some View {
#if os(iOS)
        Section(
            content: { timePeriodContent },
            header: { timePeriodHeader },
            footer: { quickFilters }
        )
#else
        ConsoleFilterSection(
            header: { timePeriodHeader },
            content: { timePeriodContent }
        )
#endif
    }

    private var timePeriodHeader: some View {
        ConsoleFilterSectionHeader(
            icon: "calendar", title: "Time Period",
            color: .yellow,
            reset: viewModel.resetDates,
            isDefault: viewModel.isDatesDefault,
            isEnabled: $viewModel.criteria.dates.isEnabled
        )
    }

    @ViewBuilder
    private var timePeriodContent: some View {
#if os(iOS) || os(macOS)
        DateRangePicker(title: "Start", date: $viewModel.criteria.dates.startDate)
        DateRangePicker(title: "End", date: $viewModel.criteria.dates.endDate)
#endif

#if os(tvOS) || os(watchOS)
        Picker("Date Range", selection: $viewModel.criteria.quickDatesFilter) {
            ForEach(ConsoleDatesQuickFilter.allCases, id: \.self) {
                Text($0.title).tag($0)
            }
        }
#endif

#if os(macOS)
        quickFilters
#endif
    }

    @ViewBuilder
    private var quickFilters: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Quick Filters")
                .lineLimit(1)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Session") { viewModel.criteria.dates = .session }
            Button("Recent") { viewModel.criteria.dates = .recent }
            Button("Today") { viewModel.criteria.dates = .today }
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
        .foregroundColor(.accentColor)
    }

    // MARK: Filters

    private var sectionFilters: some View {
        ConsoleFilterSection(
            header: {
                ConsoleFilterSectionHeader(
                    icon: "calendar", title: "General",
                    color: .blue,
                    reset: { viewModel.criteria.filters = .default },
                    isDefault: viewModel.criteria.filters == .default,
                    isEnabled: $viewModel.criteria.filters.isEnabled
                )
            },
            content: {
                ConsoleFiltersToggleCell(title: "Only Pinned", isOn: $viewModel.criteria.filters.inOnlyPins)
#if !os(macOS)
                Button.destructive(action: viewModel.removeAllPins) {
                    Text("Remove Pins")
                }
#endif
            }
        )
    }
}

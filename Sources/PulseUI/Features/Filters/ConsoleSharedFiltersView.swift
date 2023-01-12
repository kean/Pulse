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
        ConsoleFilterSection(
            header: { timePeriodHeader },
            content: { ConsoleFiltersTimePeriodCell(selection: $viewModel.criteria.dates) }
        )
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
                Button.destructive(action: viewModel.removeAllPins) {
                    Text("Remove Pins")
                }
            }
        )
    }
}

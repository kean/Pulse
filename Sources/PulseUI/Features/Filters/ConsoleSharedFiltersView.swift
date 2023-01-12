// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#warning("TODO: remove this view")
struct ConsoleSharedFiltersView: View {
    @ObservedObject var viewModel: ConsoleFiltersViewModel

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
                    icon: "gear", title: "General",
                    reset: { viewModel.criteria.general = .default },
                    isDefault: viewModel.criteria.general == .default,
                    isEnabled: $viewModel.criteria.general.isEnabled
                )
            },
            content: {
                ConsoleFiltersPinsCell(selection: $viewModel.criteria.general, removeAll: viewModel.removeAllPins)
            }
        )
    }
}

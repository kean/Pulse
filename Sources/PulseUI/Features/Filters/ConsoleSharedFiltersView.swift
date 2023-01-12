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
            content: { ConsoleFiltersTimePeriodCell(selection: $viewModel.criteria.shared.dates) }
        )
    }

    private var timePeriodHeader: some View {
        ConsoleFilterSectionHeader(icon: "calendar", title: "Time Period", filter: $viewModel.criteria.shared.dates, default: viewModel.defaultCriteria.shared.dates)
    }

    // MARK: Filters

    private var sectionFilters: some View {
        ConsoleFilterSection(
            header: {
                ConsoleFilterSectionHeader(icon: "gear", title: "General", filter: $viewModel.criteria.shared.general)
            },
            content: {
                ConsoleFiltersPinsCell(selection: $viewModel.criteria.shared.general, removeAll: viewModel.removeAllPins)
            }
        )
    }
}

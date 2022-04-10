// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(iOS)

@available(iOS 13.0, *)
struct ConsoleFiltersView: View {
    let searchCriteriaViewModel: ConsoleSearchCriteriaViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ConsoleFiltersContentView(searchCriteriaViewModel: searchCriteriaViewModel)
                .navigationBarTitle("Filters")
                .navigationBarItems(trailing: closeButton)

        }
    }

    private var closeButton: some View {
        Button(action: { self.isPresented = false }) {
            Image(systemName: "xmark.circle.fill")
                .frame(width: 44, height: 44)
        }
    }
}

@available(iOS 13.0, *)
private struct ConsoleFiltersContentView: View {
    @ObservedObject var searchCriteriaViewModel: ConsoleSearchCriteriaViewModel

    var body: some View {
        Form {
            Section {
                levelsPicker
            }
            Section {
                timePeriodPicker
                startDatePicker
                endDatePicker
            }
            Section {
                buttonResetFilters
            }
        }
    }

    private var levelsPicker: some View {
        MultiSelectionPicker(
            title: "Log Level",
            items: LoggerStore.Level.allCases.map { PickerItem(title: "\($0)", tag: $0) },
            selected: $searchCriteriaViewModel.criteria.logLevels.levels
        )
    }

    private var timePeriodPicker: some View {
        Toggle("Latest Session", isOn: $searchCriteriaViewModel.criteria.dates.isCurrentSessionOnly)
    }

    @ViewBuilder
    private var startDatePicker: some View {
        if searchCriteriaViewModel.criteria.dates.startDate == nil {
            HStack {
                Text("Start Date")
                Spacer()
                Button("Set Date") {
                    searchCriteriaViewModel.criteria.dates.isCurrentSessionOnly = false
                    searchCriteriaViewModel.criteria.dates.startDate = Date() - 1200
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.accentColor)
            }
        } else {
            DatePicker("Start Date", selection: Binding(get: {
                searchCriteriaViewModel.criteria.dates.startDate ?? Date()
            }, set: { date in
                searchCriteriaViewModel.criteria.dates.startDate = date
            }))
        }
    }

    @ViewBuilder
    private var endDatePicker: some View {
        if searchCriteriaViewModel.criteria.dates.endDate == nil {
            HStack {
                Text("End Date")
                Spacer()
                Button("Set Date") {
                    searchCriteriaViewModel.criteria.dates.isCurrentSessionOnly = false
                    searchCriteriaViewModel.criteria.dates.endDate = Date()
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.accentColor)
            }
        } else {
            DatePicker("End Date", selection: Binding(get: {
                searchCriteriaViewModel.criteria.dates.endDate ?? Date()
            }, set: { date in
                searchCriteriaViewModel.criteria.dates.endDate = date
            }))
        }
    }

    private var buttonResetFilters: some View {
        Button("Reset Filters") {
            self.searchCriteriaViewModel.resetAll()
        }
    }
}

@available(iOS 13.0, *)
struct ConsoleFiltersView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ConsoleFiltersView(searchCriteriaViewModel: .init(), isPresented: .constant(true))
        }
    }
}

#endif

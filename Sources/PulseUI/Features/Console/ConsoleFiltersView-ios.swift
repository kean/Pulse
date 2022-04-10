// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(iOS)

@available(iOS 13.0, *)
struct ConsoleFiltersView: View {
    @Binding var searchCriteria: ConsoleSearchCriteria
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ConsoleFiltersContentView(searchCriteria: $searchCriteria)
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
    @Binding var searchCriteria: ConsoleSearchCriteria

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
            selected: $searchCriteria.logLevels.levels
        )
    }

    private var timePeriodPicker: some View {
        Toggle("Latest Session", isOn: $searchCriteria.dates.isCurrentSessionOnly)
    }

    @ViewBuilder
    private var startDatePicker: some View {
        if searchCriteria.dates.startDate == nil {
            HStack {
                Text("Start Date")
                Spacer()
                Button("Set Date") {
                    searchCriteria.dates.isCurrentSessionOnly = false
                    searchCriteria.dates.startDate = Date() - 1200
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.accentColor)
            }
        } else {
            DatePicker("Start Date", selection: Binding(get: {
                searchCriteria.dates.startDate ?? Date()
            }, set: { date in
                searchCriteria.dates.startDate = date
            }))
        }
    }

    @ViewBuilder
    private var endDatePicker: some View {
        if searchCriteria.dates.endDate == nil {
            HStack {
                Text("End Date")
                Spacer()
                Button("Set Date") {
                    searchCriteria.dates.isCurrentSessionOnly = false
                    searchCriteria.dates.endDate = Date()
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.accentColor)
            }
        } else {
            DatePicker("End Date", selection: Binding(get: {
                searchCriteria.dates.endDate ?? Date()
            }, set: { date in
                searchCriteria.dates.endDate = date
            }))
        }
    }

    private var buttonResetFilters: some View {
        Button("Reset Filters") {
            self.searchCriteria = .init()
        }
    }
}

@available(iOS 13.0, *)
struct ConsoleFiltersView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ConsoleFiltersView(searchCriteria: .constant(.default), isPresented: .constant(true))
        }
    }
}

#endif

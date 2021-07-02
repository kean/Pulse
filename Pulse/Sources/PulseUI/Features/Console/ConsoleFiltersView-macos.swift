// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(macOS)

enum ConsoleFiltersViewType {
    case `default`
    case network
}

struct ConsoleFiltersView: View {
    @ObservedObject var model: ConsoleViewModel
    let type: ConsoleFiltersViewType

    var body: some View {
        HStack {
            SiderbarSectionTitle(text: "Filters")
            Button("Reset") { model.searchCriteria = .default }
                .opacity(model.searchCriteria.isDefault ? 0 : 1)
        }
        .frame(height: 16)
        .padding(.top, 16)

        if type == .default {
            logLevelsGroup
            labelsGroup
        }

        if type == .network {
            domainsGroup
        }

        timePeriodGroup
    }

    private var logLevelsGroup: some View {
        DisclosureGroup(content: {
            VStack(alignment: .leading, spacing: 6) {
                Toggle("All", isOn: Binding(get: {
                    model.searchCriteria.logLevels.count == LoggerStore.Level.allCases.count
                }, set: { isOn in
                    if isOn {
                        model.searchCriteria.logLevels = Set(LoggerStore.Level.allCases)
                    } else {
                        model.searchCriteria.logLevels = Set()
                    }
                }))
                .accentColor(Color.secondary)
                .foregroundColor(Color.secondary)
                ForEach(LoggerStore.Level.allCases, id: \.self) { item in
                    Toggle(item.rawValue.capitalized, isOn: Binding(get: {
                        model.searchCriteria.logLevels.contains(item)
                    }, set: { isOn in
                        if isOn {
                            model.searchCriteria.logLevels.insert(item)
                        } else {
                            model.searchCriteria.logLevels.remove(item)
                        }
                    }))
                    .accentColor(Color.textColor(for: item))
                    .foregroundColor(Color.textColor(for: item))
                }
            }
        }, label: {
            Label("Log Level", systemImage: "flag")
        })
    }

    private var labelsGroup: some View {
        DisclosureGroup(content: {
            VStack(alignment: .leading, spacing: 6) {
                Toggle("All", isOn: Binding(get: {
                    model.searchCriteria.hiddenLabels.isEmpty
                }, set: { isOn in
                    if isOn {
                        model.searchCriteria.hiddenLabels = []
                    } else {
                        model.searchCriteria.hiddenLabels = Set(model.allLabels)
                    }
                }))
                .accentColor(Color.secondary)
                .foregroundColor(Color.secondary)
                ForEach(model.allLabels, id: \.self) { item in
                    Toggle(item.capitalized, isOn: Binding(get: {
                        !model.searchCriteria.hiddenLabels.contains(item)
                    }, set: { isOn in
                        if isOn {
                            model.searchCriteria.hiddenLabels.remove(item)
                        } else {
                            model.searchCriteria.hiddenLabels.insert(item)
                        }
                    }))
                }
            }
        }, label: {
            Label("Labels", systemImage: "doc")
        })
    }

    private var domainsGroup: some View {
        DisclosureGroup(content: {
            Text("Upcoming")
                .foregroundColor(.secondary)
        }, label: {
            Label("Domains", systemImage: "doc")
        })
    }

    private var timePeriodGroup: some View {
        DisclosureGroup(content: {
            Toggle("Latest Session", isOn: $model.searchCriteria.isCurrentSessionOnly)
            DatePickerButton(title: "From", date: $model.searchCriteria.startDate)
            DatePickerButton(title: "To", date: $model.searchCriteria.endDate)
        }, label: {
            Label("Time Period", systemImage: "calendar")
        })
    }
}

struct ConsoleFiltersView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ConsoleFiltersView(model: ConsoleViewModel(store: .mock), type: .default)
        }
    }
}

#endif

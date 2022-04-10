// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(macOS)

enum ConsoleFiltersViewType {
    case `default`
    case network
}

struct ConsoleFiltersView: View {
    @ObservedObject var model: ConsoleSearchCriteriaViewModel
    let type: ConsoleFiltersViewType

    var body: some View {
        HStack {
            SiderbarSectionTitle(text: "Filters")
            Button("Reset") { model.criteria = .default }
                .opacity(model.criteria.isDefault ? 0 : 1)
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
                    model.criteria.logLevels.levels.count == LoggerStore.Level.allCases.count
                }, set: { isOn in
                    if isOn {
                        model.criteria.logLevels.levels = Set(LoggerStore.Level.allCases)
                    } else {
                        model.criteria.logLevels.levels = Set()
                    }
                }))
                .accentColor(Color.secondary)
                .foregroundColor(Color.secondary)
                ForEach(LoggerStore.Level.allCases, id: \.self) { item in
                    Toggle(item.rawValue.capitalized, isOn: Binding(get: {
                        model.criteria.logLevels.levels.contains(item)
                    }, set: { isOn in
                        if isOn {
                            model.criteria.logLevels.levels.insert(item)
                        } else {
                            model.criteria.logLevels.levels.remove(item)
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
                    model.criteria.labels.hidden.isEmpty
                }, set: { isOn in
                    if isOn {
                        model.criteria.labels.hidden = []
                    } else {
                        model.criteria.labels.hidden = Set(model.allLabels)
                    }
                }))
                .accentColor(Color.secondary)
                .foregroundColor(Color.secondary)
                ForEach(model.allLabels, id: \.self) { item in
                    Toggle(item.capitalized, isOn: Binding(get: {
                        !model.criteria.labels.hidden.contains(item)
                    }, set: { isOn in
                        if isOn {
                            model.criteria.labels.hidden.remove(item)
                        } else {
                            model.criteria.labels.hidden.insert(item)
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
            Toggle("Latest Session", isOn: $model.criteria.dates.isCurrentSessionOnly)
            DatePickerButton(title: "From", date: $model.criteria.dates.startDate)
            DatePickerButton(title: "To", date: $model.criteria.dates.endDate)
        }, label: {
            Label("Time Period", systemImage: "calendar")
        })
    }
}

#if DEBUG
struct ConsoleFiltersView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ConsoleFiltersView(model: .init(), type: .default)
        }
    }
}
#endif

#endif

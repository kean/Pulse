// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(macOS)

struct ConsoleFiltersView: View {
    @ObservedObject var viewModel: ConsoleSearchCriteriaViewModel
    
    @AppStorage("networkFilterIsParametersExpanded") private var isParametersExpanded = true
    @AppStorage("consoleFiltersIsLevelsSectionExpanded") private var isLevelsSectionExpanded = true
    @AppStorage("consoleFiltersIsLabelsExpanded") private var isLabelsExpanded = false
    @AppStorage("consoleFiltersIsTimePeriodExpanded") private var isTimePeriodExpanded = true

    var body: some View {
        ScrollView {
            VStack(spacing: Filters.formSpacing) {
                VStack(spacing: 6) {
                    HStack {
                        Text("FILTERS")
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Reset") { viewModel.resetAll() }
                        .disabled(!viewModel.isButtonResetEnabled)
                    }
                    Divider()
                }.padding(.top, 6)

                parametersGroup
                logLevelsGroup
                labelsGroup
                timePeriodGroup
            }.padding(Filters.formPadding)
        }
    }
    
    private var parametersGroup: some View {
        DisclosureGroup(isExpanded: $isParametersExpanded, content: {
            VStack {
                ForEach(viewModel.filters) { filter in
                    CustomFilterView(filter: filter, onRemove: {
                        viewModel.removeFilter(filter)
                    })
                }
            }.padding(.top, Filters.contentTopInset)
            Button(action: viewModel.addFilter) {
                Image(systemName: "plus.circle")
            }
        }, label: {
            FilterSectionHeader(
                icon: "line.horizontal.3.decrease.circle", title: "General",
                color: .yellow,
                reset: { viewModel.resetFilters() },
                isDefault: viewModel.filters.count == 1 && viewModel.filters[0].isDefault,
                isEnabled: $viewModel.criteria.isFiltersEnabled
            )
        })
    }

    private var logLevelsGroup: some View {
        DisclosureGroup(isExpanded: $isLevelsSectionExpanded, content: {
            HStack(spacing:0) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("All", isOn: viewModel.bindingForTogglingAllLevels)
                        .accentColor(Color.secondary)
                        .foregroundColor(Color.secondary)
                    
                    HStack(spacing: 18) {
                        makeLevelsSection(with: [.trace, .debug, .info, .notice])
                        makeLevelsSection(with: [.warning, .error, .critical])
                    }.fixedSize()
                }
                Spacer()
            }
            .padding(.leading, 13)
            .padding(.top, Filters.contentTopInset)
        }, label: {
            FilterSectionHeader(
                icon: "flag", title: "Levels",
                color: .accentColor,
                reset: { viewModel.criteria.logLevels = .default },
                isDefault: false,
                isEnabled: $viewModel.criteria.logLevels.isEnabled
            )
        })
    }
    
    private func makeLevelsSection(with levels: [LoggerStore.Level]) -> some View {
        VStack(alignment: .leading) {
            Spacer()
            ForEach(levels, id: \.self) { item in
                Toggle(item.rawValue.capitalized, isOn: viewModel.binding(forLevel: item))
            }
        }
    }

    private var labelsGroup: some View {
        DisclosureGroup(isExpanded: $isLabelsExpanded, content: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("All", isOn: viewModel.bindingForTogglingAllLabels)
                        .accentColor(Color.secondary)
                        .foregroundColor(Color.secondary)
                    ForEach(viewModel.allLabels, id: \.self) { item in
                        Toggle(item.capitalized, isOn: viewModel.binding(forLabel: item))
                    }
                }
                Spacer()
            }.padding(.leading, 13)
                .padding(.top, Filters.contentTopInset)
        }, label: {
            FilterSectionHeader(
                icon: "tag", title: "Labels",
                color: .orange,
                reset: { viewModel.criteria.labels = .default },
                isDefault: viewModel.criteria.labels == .default,
                isEnabled: $viewModel.criteria.labels.isEnabled
            )
        })
    }

    private var timePeriodGroup: some View {
        DisclosureGroup(isExpanded: $isTimePeriodExpanded, content: {
            Filters.toggle("Latest Session", isOn: $viewModel.criteria.dates.isCurrentSessionOnly)
                .padding(.top, Filters.contentTopInset)

            Filters.toggle("Start Date", isOn: $viewModel.criteria.dates.isStartDateEnabled)
            HStack(spacing: 0) {
                DatePicker("", selection: viewModel.bindingStartDate)
                    .disabled(!viewModel.criteria.dates.isStartDateEnabled)
                    .fixedSize()
                Spacer()
            }

            Filters.toggle("End Date", isOn: $viewModel.criteria.dates.isEndDateEnabled)
            HStack(spacing: 0) {
                DatePicker("", selection: viewModel.bindingEndDate)
                    .disabled(!viewModel.criteria.dates.isEndDateEnabled)
                    .fixedSize()
                Spacer()
            }
            
            HStack {
                Button("Recent") {
                    viewModel.criteria.dates = .recent
                }
                Button("Today") {
                    viewModel.criteria.dates = .today
                }
                Spacer()
            }.padding(.leading, 13)
        }, label: {
            FilterSectionHeader(
                icon: "calendar", title: "Time Period",
                color: .yellow,
                reset: { viewModel.criteria.dates = .default },
                isDefault: viewModel.criteria.dates == .default,
                isEnabled: $viewModel.criteria.dates.isEnabled
            )
        })
    }
}

private struct CustomFilterView: View {
    @ObservedObject var filter: ConsoleSearchFilter
    let onRemove: () -> Void
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                fieldPicker
                Spacer()
                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(Color.red)
                Button(action: { filter.isEnabled.toggle() }) {
                    Image(systemName: filter.isEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(PlainButtonStyle())
            }
            HStack {
                matchPicker
                Spacer()
            }
            HStack {
                TextField("Value", text: $filter.value)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.leading, 6)
                    .padding(.trailing, 2)
            }
        }
        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 4))
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }
    
    private var fieldPicker: some View {
        Picker("", selection: $filter.field) {
            Section {
                Text("Level").tag(ConsoleSearchFilter.Field.level)
                Text("Label").tag(ConsoleSearchFilter.Field.label)
                Text("Message").tag(ConsoleSearchFilter.Field.message)
            }
            Section {
                Text("Metadata").tag(ConsoleSearchFilter.Field.metadata)
            }
            Section {
                Text("File").tag(ConsoleSearchFilter.Field.file)
                Text("Function").tag(ConsoleSearchFilter.Field.function)
                Text("Line").tag(ConsoleSearchFilter.Field.line)
            }
        }.frame(width: 120)
    }
    
    private var matchPicker: some View {
        Picker("", selection: $filter.match) {
            Section {
                Text("Contains").tag(ConsoleSearchFilter.Match.contains)
                Text("Not Contains").tag(ConsoleSearchFilter.Match.notContains)
            }
            Section {
                Text("Equals").tag(ConsoleSearchFilter.Match.equal)
                Text("Not Equals").tag(ConsoleSearchFilter.Match.notEqual)
            }
            Section {
                Text("Begins With").tag(ConsoleSearchFilter.Match.beginsWith)
            }
            Section {
                Text("Regex").tag(ConsoleSearchFilter.Match.regex)
            }
        }.frame(width: 120)
    }
}

#if DEBUG
struct ConsoleFiltersPanelPro_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ConsoleFiltersView(viewModel: .init())
                .previewLayout(.fixed(width: 190, height: 800))
        }
    }
}
#endif

#endif

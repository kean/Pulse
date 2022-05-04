// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS)

@available(iOS 13.0, *)
struct ConsoleFiltersView: View {
    @ObservedObject var viewModel: ConsoleSearchCriteriaViewModel

    @State private var isAllLabelsShown = false
    @Binding var isPresented: Bool

    var body: some View {
        Form {
            if #available(iOS 14.0, *) {
                Section(header: FilterSectionHeader(
                    icon: "line.horizontal.3.decrease.circle", title: "Filters",
                    color: .yellow,
                    reset: { viewModel.resetFilters() },
                    isDefault: viewModel.filters.count == 1 && viewModel.filters[0].isDefault
                )) {
                    customFiltersGroup
                }
            }
            
            Section(header: FilterSectionHeader(
                icon: "flag", title: "Levels",
                color: .accentColor,
                reset: { viewModel.criteria.logLevels = .default },
                isDefault: viewModel.criteria.logLevels == .default
            )) {
                logLevelsGroup
            }
            
            Section(header: FilterSectionHeader(
                icon: "tag", title: "Labels",
                color: .orange,
                reset: { viewModel.criteria.labels = .default },
                isDefault: viewModel.criteria.labels == .default
            )) {
                labelsGroup
            }
            
            Section(header: FilterSectionHeader(
                icon: "calendar", title: "Time Period",
                color: .yellow,
                reset: { viewModel.criteria.dates = .default },
                isDefault: viewModel.criteria.dates == .default
            )) {
                timePeriodGroup
            }
        }
        .background(allLabelsNavigationLink)
        .navigationBarTitle("Filters")
        .navigationBarItems(leading: buttonClose, trailing: buttonReset)
    }

    private var buttonClose: some View {
        Button("Close") { isPresented = false }
    }

    private var buttonReset: some View {
        Button("Reset") { viewModel.resetAll() }
            .disabled(!viewModel.isButtonResetEnabled)
    }

    @available(iOS 14.0, *)
    @ViewBuilder
    private var customFiltersGroup: some View {
        ForEach(viewModel.filters) { filter in
            CustomFilterView(filter: filter, onRemove: {
                viewModel.removeFilter(filter)
            }).buttonStyle(.plain)
        }

        Button(action: { viewModel.addFilter() }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                Text("Add Filter")
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var logLevelsGroup: some View {
        HStack(spacing: 32) {
            makeLevelsSection(levels: [.trace, .debug, .info, .notice])
            makeLevelsSection(levels: [.warning, .error, .critical])
        }
        .padding(.bottom, 6)
        .buttonStyle(.plain)

        Button(viewModel.bindingForTogglingAllLevels.wrappedValue ? " Disable All" : "Enable All", action: { viewModel.bindingForTogglingAllLevels.wrappedValue.toggle() })
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func makeLevelsSection(levels: [LoggerStore.Level]) -> some View {
        VStack(alignment: .leading) {
            Spacer()
            ForEach(levels, id: \.self) { level in
                BadgePickerItemView(title: level.rawValue.capitalized, isEnabled: viewModel.binding(forLevel: level), textColor: tintColor(for: level))
                    .accentColor(tintColor(for: level))
            }
        }
    }

    @ViewBuilder
    private var labelsGroup: some View {
        let labels = viewModel.allLabels

        if labels.isEmpty {
            Text("No Labels")
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.secondary)
        } else {
            ForEach(labels.prefix(5), id: \.self) { item in
                Toggle(item.capitalized, isOn: viewModel.binding(forLabel: item))
            }
            if labels.count > 5 {
                Button("View All", action: { isAllLabelsShown = true })
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var allLabelsNavigationLink: some View {
        NavigationLink.programmatic(isActive: $isAllLabelsShown) {
            ConsoleFiltersLabelsPickerView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var timePeriodGroup: some View {
        Toggle("Latest Session", isOn: $viewModel.criteria.dates.isCurrentSessionOnly)

        DateRangePicker(title: "Start Date", date: viewModel.bindingStartDate, isEnabled: $viewModel.criteria.dates.isStartDateEnabled)
        DateRangePicker(title: "End Date", date: viewModel.bindingEndDate, isEnabled: $viewModel.criteria.dates.isEndDateEnabled)

        HStack(spacing: 16) {
            Button("Recent") { viewModel.criteria.dates = .recent }
                .foregroundColor(.accentColor)
            Button("Today") { viewModel.criteria.dates = .today }
                .foregroundColor(.accentColor)
            Spacer()
        }.buttonStyle(.plain)
    }
}

@available(iOS 14.0, *)
private struct CustomFilterView: View {
    @ObservedObject var filter: ConsoleSearchFilter
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
            .foregroundColor(Color.red)

            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    fieldPicker
                    Spacer().frame(width: 8)
                    matchPicker
                    Spacer(minLength: 0)
                    Checkbox(isEnabled: $filter.isEnabled)
                        .disabled(filter.isDefault)
                }
                TextField("Value", text: $filter.value)
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
            }

        }
        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 4))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var fieldPicker: some View {
        Menu(content: {
            Picker("", selection: $filter.field) {
                Text("Level").tag(ConsoleSearchFilter.Field.level)
                Text("Label").tag(ConsoleSearchFilter.Field.label)
                Text("Message").tag(ConsoleSearchFilter.Field.message)
                Divider()
                Text("Metadata").tag(ConsoleSearchFilter.Field.metadata)
                Divider()
                Text("File").tag(ConsoleSearchFilter.Field.file)
                Text("Function").tag(ConsoleSearchFilter.Field.function)
                Text("Line").tag(ConsoleSearchFilter.Field.line)
            }
        }, label: {
            FilterPickerButton(title: filter.field.localizedTitle)
        }).animation(.none)
    }

    private var matchPicker: some View {
        Menu(content: {
            Picker("", selection: $filter.match) {
                Text("Contains").tag(ConsoleSearchFilter.Match.contains)
                Text("Not Contains").tag(ConsoleSearchFilter.Match.notContains)
                Divider()
                Text("Equals").tag(ConsoleSearchFilter.Match.equal)
                Text("Not Equals").tag(ConsoleSearchFilter.Match.notEqual)
                Divider()
                Text("Begins With").tag(ConsoleSearchFilter.Match.beginsWith)
                Divider()
                Text("Regex").tag(ConsoleSearchFilter.Match.regex)
            }
        }, label: {
            FilterPickerButton(title: filter.match.localizedTitle)
        }).animation(.none)
    }
}

@available(iOS 13.0, *)
private func tintColor(for level: LoggerStore.Level) -> Color {
    switch level {
    case .trace, .debug: return Color.primary.opacity(0.66)
    default: return Color.textColor(for: level)
    }
}


// MARK: - Preview

@available(iOS 13.0, *)
struct ConsoleFiltersPanelPro_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                ConsoleFiltersView(viewModel: .init(), isPresented: .constant(true))
            }
        }
    }
}

#endif

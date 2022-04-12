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
                    isDefault: viewModel.filters.count == 1 && viewModel.filters[0].isDefault,
                    isEnabled: $viewModel.criteria.isFiltersEnabled
                )) {
                    customFiltersGroup
                }
            }
            Section(header: FilterSectionHeader(
                icon: "flag", title: "Levels",
                color: .accentColor,
                reset: { viewModel.criteria.logLevels = .default },
                isDefault: viewModel.criteria.logLevels == .default,
                isEnabled: $viewModel.criteria.logLevels.isEnabled
            )) {
                logLevelsGroup
            }
            Section(header: FilterSectionHeader(
                icon: "tag", title: "Labels",
                color: .orange,
                reset: { viewModel.criteria.labels = .default },
                isDefault: viewModel.criteria.labels == .default,
                isEnabled: $viewModel.criteria.labels.isEnabled
            )) {
                labelsGroup
            }
            Section(header: FilterSectionHeader(
                icon: "calendar", title: "Time Period",
                color: .yellow,
                reset: { viewModel.criteria.dates = .default },
                isDefault: viewModel.criteria.dates == .default,
                isEnabled: $viewModel.criteria.dates.isEnabled
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
            Button("Today") { viewModel.criteria.dates = .today }
            Spacer()
        }.buttonStyle(.plain)
    }
}

@available(iOS 13.0, *)
private struct DateRangePicker: View {
    let title: String
    @Binding var date: Date
    @Binding var isEnabled: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Toggle(title, isOn: $isEnabled)
                    .fixedSize()
                    .labelsHidden()
            }
            HStack {
                DatePicker(title, selection: $date)
                    .labelsHidden()
                Spacer()
            }
        }.frame(height: 84)
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
            .buttonStyle(PlainButtonStyle())
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
            makePickerButton(title: filter.field.localizedTitle)
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
            makePickerButton(title: filter.match.localizedTitle)
        }).animation(.none)
    }
    
    private func makePickerButton(title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .foregroundColor(Color.primary.opacity(0.9))
        .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
        .background(Color.secondaryFill)
        .cornerRadius(8)
    }
}

@available(iOS 13.0, *)
struct FilterSectionHeader: View {
    let icon: String
    let title: String
    let color: Color
    let reset: () -> Void
    let isDefault: Bool
    @Binding var isEnabled: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
            }
            Spacer()

            Button(action: reset) {
                Image(systemName: "arrow.uturn.left")
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)
            }
            .frame(width: 34, height: 34)
            .disabled(isDefault)
            
            Toggle("", isOn: $isEnabled)
                .fixedSize()
                .disabled(isDefault)
        }.buttonStyle(.plain)
    }
}

@available(iOS 13.0, *)
private func tintColor(for level: LoggerStore.Level) -> Color {
    switch level {
    case .trace, .debug: return Color.primary.opacity(0.66)
    default: return Color.textColor(for: level)
    }
}

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

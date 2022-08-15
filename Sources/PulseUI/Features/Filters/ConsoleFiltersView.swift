// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS) || os(macOS)

struct ConsoleFiltersView: View {
    @ObservedObject var viewModel: ConsoleSearchCriteriaViewModel

#if os(iOS)
    @State var isGeneralSectionExpanded = true
    @State var isLevelsSectionExpanded = true
    @State var isLabelsSectionExpanded = false
    @State var isTimePeriodSectionExpanded = true

    @State var isAllLabelsShown = false

    @Binding var isPresented: Bool

    var body: some View {
        Form { formContents }
            .navigationBarTitle("Filters", displayMode: .inline)
            .navigationBarItems(leading: buttonClose, trailing: buttonReset)
    }

    private var buttonClose: some View {
        Button("Close") { isPresented = false }
    }
#else
    @AppStorage("networkFilterIsParametersExpanded") var isGeneralSectionExpanded = true
    @AppStorage("consoleFiltersIsLevelsSectionExpanded") var isLevelsSectionExpanded = true
    @AppStorage("consoleFiltersIsLabelsExpanded") var isLabelsSectionExpanded = false
    @AppStorage("consoleFiltersIsTimePeriodExpanded") var isTimePeriodSectionExpanded = true

    var body: some View {
        ScrollView {
            VStack(spacing: Filters.formSpacing) {
                VStack(spacing: 6) {
                    HStack {
                        Text("FILTERS")
                            .foregroundColor(.secondary)
                        Spacer()
                        buttonReset
                    }
                    Divider()
                }
                .padding(.top, 6)

                formContents
            }.padding(Filters.formPadding)
        }
    }
#endif
}

// MARK: - ConsoleFiltersView (Contents)

extension ConsoleFiltersView {
    @ViewBuilder
    var formContents: some View {
        if #available(iOS 14.0, *) {
            generalSection
        }
        logLevelsSection
        labelsSection
        timePeriodSection
    }

    var buttonReset: some View {
        Button("Reset") { viewModel.resetAll() }
            .disabled(!viewModel.isButtonResetEnabled)
    }
}

// MARK: - ConsoleFiltersView (Custom Filters)

extension ConsoleFiltersView {
    @available(iOS 14.0, *)
    var generalSection: some View {
        FiltersSection(
            isExpanded: $isGeneralSectionExpanded,
            header: { generalHeader },
            content: { generalContent },
            isWrapped: false
        )
    }

    private var generalHeader: some View {
        FilterSectionHeader(
            icon: "line.horizontal.3.decrease.circle", title: "General",
            color: .yellow,
            reset: { viewModel.resetFilters() },
            isDefault: viewModel.filters.count == 1 && viewModel.filters[0].isDefault,
            isEnabled: $viewModel.criteria.isFiltersEnabled
        )
    }

#if os(iOS)
    @available(iOS 14.0, *)
    @ViewBuilder
    private var generalContent: some View {
        ForEach(viewModel.filters) { filter in
            CustomFilterView(filter: filter, onRemove: {
                viewModel.removeFilter(filter)
            }).buttonStyle(.plain)
        }

        Button(action: { viewModel.addFilter() }) {
            HStack {
                Image(systemName: "plus.circle")
                    .font(.system(size: 18))
                Text("Add Filter")
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
#else
    @ViewBuilder
    private var generalContent: some View {
        VStack {
            ForEach(viewModel.filters) { filter in
                CustomFilterView(filter: filter, onRemove: {
                    viewModel.removeFilter(filter)
                })
            }
        }
        .padding(.leading, 4)
        .padding(.top, Filters.contentTopInset)

        Button(action: viewModel.addFilter) {
            Image(systemName: "plus.circle")
        }
    }
#endif
}

// MARK: - ConsoleFiltersView (Log Levels)

extension ConsoleFiltersView {
    var logLevelsSection: some View {
        FiltersSection(
            isExpanded: $isLevelsSectionExpanded,
            header: { logLevelsHeader },
            content: { logLevelsContent }
        )
    }

    private var logLevelsHeader: some View {
        FilterSectionHeader(
            icon: "flag", title: "Levels",
            color: .accentColor,
            reset: { viewModel.criteria.logLevels = .default },
            isDefault: false,
            isEnabled: $viewModel.criteria.logLevels.isEnabled
        )
    }

#if os(iOS)
    @ViewBuilder
    private var logLevelsContent: some View {
        HStack(spacing: 16) {
            makeLevelsSection(levels: [.trace, .debug, .info, .notice])
            Divider()
            makeLevelsSection(levels: [.warning, .error, .critical])
        }
        .padding(.bottom, 10)
        .buttonStyle(.plain)

        Button(viewModel.bindingForTogglingAllLevels.wrappedValue ? "Disable All" : "Enable All", action: { viewModel.bindingForTogglingAllLevels.wrappedValue.toggle() })
            .frame(maxWidth: .infinity, alignment: .center)
    }
#else
    private var logLevelsContent: some View {
        HStack(spacing:0) {
            VStack(alignment: .leading, spacing: 6) {
                Toggle("All", isOn: viewModel.bindingForTogglingAllLevels)
                    .accentColor(Color.secondary)
                    .foregroundColor(Color.secondary)
                HStack(spacing: 32) {
                    makeLevelsSection(levels: [.trace, .debug, .info, .notice])
                    makeLevelsSection(levels: [.warning, .error, .critical])
                }.fixedSize()
            }
            Spacer()
        }
    }
#endif

    private func makeLevelsSection(levels: [LoggerStore.Level]) -> some View {
        VStack(alignment: .leading) {
            Spacer()
            ForEach(levels, id: \.self) { level in
                Toggle(level.name.capitalized, isOn: viewModel.binding(forLevel: level))
                    .accentColor(tintColor(for: level))
            }
        }
    }

    private func tintColor(for level: LoggerStore.Level) -> Color {
        switch level {
        case .trace, .debug: return Color.primary.opacity(0.66)
        default: return Color.textColor(for: level)
        }
    }
}

// MARK: - ConsoleFiltersView (Labels)

extension ConsoleFiltersView {
    var labelsSection: some View {
        FiltersSection(
            isExpanded: $isLabelsSectionExpanded,
            header: { labelsHeader },
            content: { labelsContent }
        )
    }

    private var labelsHeader: some View {
        FilterSectionHeader(
            icon: "tag", title: "Labels",
            color: .orange,
            reset: { viewModel.criteria.labels = .default },
            isDefault: viewModel.criteria.labels == .default,
            isEnabled: $viewModel.criteria.labels.isEnabled
        )
    }

#if os(iOS)
    @ViewBuilder
    private var labelsContent: some View {
        let labels = viewModel.allLabels

        if labels.isEmpty {
            Text("No Labels")
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.secondary)
        } else {
            ForEach(labels.prefix(4), id: \.self) { item in
                Toggle(item.capitalized, isOn: viewModel.binding(forLabel: item))
            }
            if labels.count > 4 {
                Button("View All", action: { isAllLabelsShown = true })
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(allLabelsNavigationLink)
            }
        }
    }

    private var allLabelsNavigationLink: some View {
        InvisibleNavigationLinks {
            NavigationLink.programmatic(isActive: $isAllLabelsShown) {
                ConsoleFiltersLabelsPickerView(viewModel: viewModel)
            }
        }
    }
#else
    private var labelsContent: some View {
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
        }
    }
#endif
}

// MARK: - ConsoleFiltersView (Time Period)

extension ConsoleFiltersView {
    var timePeriodSection: some View {
        FiltersSection(
            isExpanded: $isTimePeriodSectionExpanded,
            header: { timePeriodHeader },
            content: { timePeriodContent }
        )
    }

    private var timePeriodHeader: some View {
        FilterSectionHeader(
            icon: "calendar", title: "Time Period",
            color: .yellow,
            reset: { viewModel.criteria.dates = .default },
            isDefault: viewModel.criteria.dates == .default,
            isEnabled: $viewModel.criteria.dates.isEnabled
        )
    }

    @ViewBuilder
    private var timePeriodContent: some View {
        Filters.toggle("Latest Session", isOn: $viewModel.criteria.dates.isCurrentSessionOnly)

        DateRangePicker(title: "Start Date", date: viewModel.bindingStartDate, isEnabled: $viewModel.criteria.dates.isStartDateEnabled)
        DateRangePicker(title: "End Date", date: viewModel.bindingEndDate, isEnabled: $viewModel.criteria.dates.isEndDateEnabled)

        HStack(spacing: 16) {
            Button("Recent") { viewModel.criteria.dates = .recent }
            Button("Today") { viewModel.criteria.dates = .today }
            Spacer()
        }
#if os(iOS)
        .foregroundColor(.accentColor)
        .buttonStyle(.plain)
#elseif os(macOS)
        .padding(.top, 6)
#endif
    }
}

#if DEBUG
struct ConsoleFiltersView_Previews: PreviewProvider {
    static var previews: some View {
#if os(iOS)
        NavigationView {
            ConsoleFiltersView(viewModel: makeMockViewModel(), isPresented: .constant(true))
        }
#else
        ConsoleFiltersView(viewModel: makeMockViewModel())
            .previewLayout(.fixed(width: Filters.preferredWidth - 15, height: 700))
#endif
    }
}

private func makeMockViewModel() -> ConsoleSearchCriteriaViewModel {
    ConsoleSearchCriteriaViewModel(store: .mock)
}
#endif

#endif

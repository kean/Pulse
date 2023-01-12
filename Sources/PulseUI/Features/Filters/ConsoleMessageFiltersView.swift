// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleMessageFiltersView: View {
    @ObservedObject var viewModel: ConsoleSearchCriteriaViewModel

#if os(iOS) || os(tvOS) || os(watchOS)
    var body: some View {
        Form { formContents }
#if os(iOS)
            .navigationBarItems(leading: buttonReset)
#endif
    }
#else
    var body: some View {
        ScrollView {
            formContents.frame(width: 320)
        }
    }
#endif
}

// MARK: - ConsoleMessageFiltersView (Contents)

extension ConsoleMessageFiltersView {
    @ViewBuilder
    var formContents: some View {
#if os(tvOS) || os(watchOS)
        Section {
            buttonReset
        }
#endif
        ConsoleSharedFiltersView(viewModel: viewModel)
#if os(iOS) || os(macOS)
        if #available(iOS 15, *) {
            generalSection
        }
#endif
        logLevelsSection
        labelsSection
    }

    var buttonReset: some View {
        Button("Reset", action: viewModel.resetAll)
            .disabled(!viewModel.isButtonResetEnabled)
    }
}

// MARK: - ConsoleMessageFiltersView (Custom Filters)

#if os(iOS) || os(macOS)
@available(iOS 15, *)
extension ConsoleMessageFiltersView {
    var generalSection: some View {
        ConsoleFilterSection(
            header: { generalHeader },
            content: { generalContent }
        )
    }

    private var generalHeader: some View {
        ConsoleFilterSectionHeader(icon: "line.horizontal.3.decrease.circle", title: "Filters", filter: $viewModel.criteria.messages.custom)
    }

#if os(iOS) || os(tvOS)
    @ViewBuilder
    private var generalContent: some View {
        customFiltersList
        if !isCustomFiltersDefault {
            Button(action: { viewModel.criteria.messages.custom.filters.append(.default) }) {
                Text("Add Filter").frame(maxWidth: .infinity)
            }
        }
    }
#else
    @ViewBuilder
    private var generalContent: some View {
        VStack {
            customFiltersList
        }.padding(.leading, -8)

        if !isCustomFiltersDefault {
            Button(action: viewModel.addFilter) {
                Image(systemName: "plus.circle")
            }.padding(.top, 6)
        }
    }
#endif

    private var customFiltersList: some View {
        ForEach($viewModel.criteria.messages.custom.filters) { filter in
            ConsoleCustomMessageFilterView(filter: filter, onRemove: isCustomFiltersDefault ? nil  : { viewModel.remove(filter.wrappedValue) })
        }
    }

    private var isCustomFiltersDefault: Bool {
        viewModel.criteria.messages.custom == .default
    }
}
#endif

// MARK: - ConsoleMessageFiltersView (Log Levels)

extension ConsoleMessageFiltersView {
    var logLevelsSection: some View {
        ConsoleFilterSection(
            header: { logLevelsHeader },
            content: { logLevelsContent }
        )
    }

    private var logLevelsHeader: some View {
        ConsoleFilterSectionHeader(icon: "flag", title: "Levels", filter: $viewModel.criteria.messages.logLevels)
    }

#if os(macOS)
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

    private func makeLevelsSection(levels: [LoggerStore.Level]) -> some View {
        VStack(alignment: .leading) {
            Spacer()
            ForEach(levels, id: \.self) { level in
                Toggle(level.name.capitalized, isOn: viewModel.binding(forLevel: level))
            }
        }
    }
#else
    @ViewBuilder
    private var logLevelsContent: some View {
        ForEach(LoggerStore.Level.allCases, id: \.self) { level in
            Checkbox(level.name.capitalized, isOn: viewModel.binding(forLevel: level))
        }
        Button(viewModel.bindingForTogglingAllLevels.wrappedValue ? "Disable All" : "Enable All") {
            viewModel.bindingForTogglingAllLevels.wrappedValue.toggle()
        }
    }
#endif
}

// MARK: - ConsoleMessageFiltersView (Labels)

extension ConsoleMessageFiltersView {
    var labelsSection: some View {
        ConsoleFilterSection(
            header: { labelsHeader },
            content: { labelsContent }
        )
    }

    private var labelsHeader: some View {
        ConsoleFilterSectionHeader(icon: "tag", title: "Labels", filter: $viewModel.criteria.messages.labels)
    }

#if os(macOS)
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
#else
    @ViewBuilder
    private var labelsContent: some View {
        let labels = viewModel.labels.objects.map(\.name)

        if labels.isEmpty {
            Text("No Labels")
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.secondary)
        } else {
            ForEach(labels.prefix(4), id: \.self) { item in
                Checkbox(item.capitalized, isOn: viewModel.binding(forLabel: item))
            }
            if labels.count > 4 {
                NavigationLink(destination: ConsoleFiltersLabelsPickerView(viewModel: viewModel)) {
                    Text("View All").foregroundColor(.blue)
                }
            }
        }
    }
#endif
}

#if DEBUG
struct ConsoleMessageFiltersView_Previews: PreviewProvider {
    static var previews: some View {
#if os(macOS)
        ConsoleMessageFiltersView(viewModel: .init(store: .mock))
            .previewLayout(.fixed(width: 320, height: 900))
#else
        NavigationView {
            ConsoleMessageFiltersView(viewModel: .init(store: .mock))
        }.navigationViewStyle(.stack)
#endif
    }
}
#endif

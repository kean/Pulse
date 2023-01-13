// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleSearchView: View {
    @ObservedObject var viewModel: ConsoleSearchViewModel

    @State private var isRedirectGroupExpanded = true
    @State private var isDomainsPickerPresented = false

#if os(iOS) || os(watchOS) || os(tvOS)
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

// MARK: - ConsoleSearchView (Contents)

extension ConsoleSearchView {
    @ViewBuilder
    var formContents: some View {
#if os(tvOS) || os(watchOS)
        Section {
            buttonReset
        }
#endif
        sharedCriteriaView

        switch viewModel.mode {
        case .messages: messagesCriteriaView
        case .network: networkCriteriaView
        }
    }

    @ViewBuilder
    private var messagesCriteriaView: some View {
#if os(iOS) || os(macOS)
        if #available(iOS 15, *) {
            generalSection
        }
#endif
        logLevelsSection
        labelsSection
    }

    @ViewBuilder
    private var networkCriteriaView: some View {
#if os(iOS) || os(macOS)
        if #available(iOS 15, *) {
            generalGroup
        }
#endif
        responseGroup
        domainsGroup
        networkingGroup
    }

    var buttonReset: some View {
        Button.destructive(action: viewModel.resetAll) { Text("Reset") }
            .disabled(!viewModel.isButtonResetEnabled)
    }
}

// MARK: - Shared

extension ConsoleSearchView {
    @ViewBuilder
    var sharedCriteriaView: some View {
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

// MARK: - ConsoleSearchView (General)

#if os(iOS) || os(macOS)

@available(iOS 15, *)
extension ConsoleSearchView {
    var generalGroup: some View {
        ConsoleFilterSection(
            header: { generalGroupHeader },
            content: { generalGroupContent }
        )
    }

    private var generalGroupHeader: some View {
        ConsoleFilterSectionHeader(icon: "line.horizontal.3.decrease.circle", title: "Filters", filter: $viewModel.criteria.network.custom)
    }

#if os(iOS)
    @ViewBuilder
    private var generalGroupContent: some View {
        customFilersList
        if !(viewModel.criteria.network.custom == .init()) {
            Button(action: { viewModel.criteria.network.custom.filters.append(.default) }) {
                Text("Add Filter").frame(maxWidth: .infinity)
            }
        }
    }
#elseif os(macOS)
    @ViewBuilder
    private var generalGroupContent: some View {
        VStack {
            customFilersList
        }.padding(.leading, -8)

        if !(viewModel.criteria.network.custom == .init()) {
            Button(action: { viewModel.criteria.network.custom.filters.append(.default) }) {
                Image(systemName: "plus.circle")
            }.padding(.top, 6)
        }
    }
#endif

    @ViewBuilder var customFilersList: some View {
        ForEach($viewModel.criteria.network.custom.filters) { filter in
            ConsoleCustomNetworkFilterView(filter: filter, onRemove: viewModel.criteria.network.custom.filters.count > 1  ? { viewModel.remove(filter.wrappedValue) } : nil)
        }
    }
}

#endif

// MARK: - ConsoleSearchView (Response)

extension ConsoleSearchView {
    var responseGroup: some View {
        ConsoleFilterSection(
            header: { responseGroupHeader },
            content: { responseGroupContent }
        )
    }

    private var responseGroupHeader: some View {
        ConsoleFilterSectionHeader(icon: "arrow.down.circle", title:  "Response", filter: $viewModel.criteria.network.response)
    }

    @ViewBuilder
    private var responseGroupContent: some View {
#if os(iOS) || os(macOS)
        ConsoleFiltersStatusCodeCell(selection: $viewModel.criteria.network.response.statusCode.range)
        ConsoleFiltersDurationCell(selection: $viewModel.criteria.network.response.duration)
        ConsoleFiltersResponseSizeCell(selection: $viewModel.criteria.network.response.responseSize)
#endif
        ConsoleFiltersContentTypeCell(selection: $viewModel.criteria.network.response.contentType.contentType)
    }
}

// MARK: - ConsoleSearchView (Domains)

extension ConsoleSearchView {
    var domainsGroup: some View {
        ConsoleFilterSection(
            header: { domainsGroupHeader },
            content: { domainsGroupContent }
        )
    }

    private var domainsGroupHeader: some View {
        ConsoleFilterSectionHeader(icon: "server.rack", title: "Hosts", filter: $viewModel.criteria.network.host)
    }

    @ViewBuilder
    private var domainsGroupContent: some View {
        makeDomainPicker(limit: 4)
        if viewModel.domains.objects.count > 4 {
            domainsShowAllButton
        }
    }

#if os(macOS)
    private var domainsShowAllButton: some View {
        HStack {
            Spacer()
            Button(action: { isDomainsPickerPresented = true }) {
                Text("Show All")
            }
            .padding(.top, 6)
            .popover(isPresented: $isDomainsPickerPresented) {
                domainsPickerView.frame(width: 380, height: 420)
            }
            Spacer()
        }
    }

    private func makeDomainPicker(limit: Int? = nil) -> some View {
        var domains = viewModel.domains.objects.map(\.value)
        if let limit = limit {
            domains = Array(domains.prefix(limit))
        }
        return ForEach(domains, id: \.self) { domain in
            Toggle(domain, isOn: viewModel.binding(forDomain: domain))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
#else
    private var domainsShowAllButton: some View {
        NavigationLink(destination: { domainsPickerView }) {
            Text("Show All")
        }
    }

    private func makeDomainPicker(limit: Int? = nil) -> some View {
        var domains = viewModel.domains.objects.map(\.value)
        if let limit = limit {
            domains = Array(domains.prefix(limit))
        }
        return ForEach(domains, id: \.self) { domain in
            Checkbox(domain, isOn: viewModel.binding(forDomain: domain))
                .lineLimit(4)
        }
    }
#endif

    // TODO: Add search
    private var domainsPickerView: some View {
        List {
            Button("Deselect All") {
                viewModel.criteria.network.host.ignoredHosts = Set(viewModel.domains.objects.map(\.value))
            }
            makeDomainPicker()
        }
        .inlineNavigationTitle("Select Hosts")
    }
}

// MARK: - ConsoleSearchView (Networking)

extension ConsoleSearchView {
    var networkingGroup: some View {
        ConsoleFilterSection(
            header: { networkingGroupHeader },
            content: { networkingGroupContent }
        )
    }

    private var networkingGroupHeader: some View {
        ConsoleFilterSectionHeader(icon: "arrowshape.zigzag.right", title: "Networking", filter: $viewModel.criteria.network.networking)
    }

    @ViewBuilder
    private var networkingGroupContent: some View {
        ConsoleFiltersTaskTypeCell(selection: $viewModel.criteria.network.networking.taskType)
        ConsoleFiltersResponseSourceCell(selection: $viewModel.criteria.network.networking.source)
        ConsoleFiltersToggleCell(title: "Redirect", isOn: $viewModel.criteria.network.networking.isRedirect)
    }
}

// MARK: - ConsoleSearchView (Custom Filters)

#if os(iOS) || os(macOS)
@available(iOS 15, *)
extension ConsoleSearchView {
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
            Button(action: { viewModel.criteria.messages.custom.filters.append(.default) }) {
                Image(systemName: "plus.circle")
            }.padding(.top, 6)
        }
    }
#endif

    private var customFiltersList: some View {
        ForEach($viewModel.criteria.messages.custom.filters) { filter in
            ConsoleCustomMessageFilterView(filter: filter, onRemove: viewModel.criteria.messages.custom.filters.count > 1  ? { viewModel.remove(filter.wrappedValue) } : nil)
        }
    }

    private var isCustomFiltersDefault: Bool {
        viewModel.criteria.messages.custom == .init()
    }
}
#endif

// MARK: - ConsoleSearchView (Log Levels)

extension ConsoleSearchView {
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

// MARK: - ConsoleSearchView (Labels)

extension ConsoleSearchView {
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
        let labels = viewModel.labels.objects.map(\.name)
        return HStack {
            VStack(alignment: .leading, spacing: 6) {
                Toggle("All", isOn: viewModel.bindingForTogglingAllLabels)
                    .accentColor(Color.secondary)
                    .foregroundColor(Color.secondary)
                // TODO: This should display only the prefix
                ForEach(labels, id: \.self) { item in
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
struct ConsoleSearchView_Previews: PreviewProvider {
    static var previews: some View {
#if os(macOS)
        ConsoleSearchView(viewModel: .init(store: .mock))
            .previewLayout(.fixed(width: 320, height: 900))
#else
        NavigationView {
            ConsoleSearchView(viewModel: .init(store: .mock))
        }.navigationViewStyle(.stack)
#endif
    }
}
#endif

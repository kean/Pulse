// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleNetworkFiltersView: View {
    @ObservedObject var viewModel: ConsoleNetworkSearchCriteriaViewModel
    @ObservedObject var sharedCriteriaViewModel: ConsoleSharedSearchCriteriaViewModel

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

// MARK: - NetworkFiltersView (Contents)

extension ConsoleNetworkFiltersView {
    @ViewBuilder
    var formContents: some View {
#if os(tvOS) || os(watchOS)
        Section {
            buttonReset
        }
#endif
        ConsoleSharedFiltersView(viewModel: sharedCriteriaViewModel)
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
        Button("Reset") {
            viewModel.resetAll()
            sharedCriteriaViewModel.resetAll()
        }.disabled(!(viewModel.isButtonResetEnabled || sharedCriteriaViewModel.isButtonResetEnabled))
    }
}

// MARK: - NetworkFiltersView (General)

#if os(iOS) || os(macOS)

@available(iOS 15, *)
extension ConsoleNetworkFiltersView {
    var generalGroup: some View {
        ConsoleFilterSection(
            header: { generalGroupHeader },
            content: { generalGroupContent }
        )
    }

    private var generalGroupHeader: some View {
        ConsoleFilterSectionHeader(
            icon: "line.horizontal.3.decrease.circle", title: "Filters",
            color: .yellow,
            reset: { viewModel.resetFilters() },
            isDefault: viewModel.isDefaultFilters,
            isEnabled: $viewModel.criteria.isFiltersEnabled
        )
    }

#if os(iOS)
    @ViewBuilder
    private var generalGroupContent: some View {
        customFilersList
        if !viewModel.isDefaultFilters {
            Button(action: viewModel.addFilter) {
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

        if !viewModel.isDefaultFilters {
            Button(action: viewModel.addFilter) {
                Image(systemName: "plus.circle")
            }.padding(.top, 6)
        }
    }
#endif

    @ViewBuilder var customFilersList: some View {
        ForEach(viewModel.filters) { filter in
            ConsoleCustomNetworkFilterView(filter: filter, onRemove: viewModel.removeFilter, isRemoveHidden: viewModel.isDefaultFilters)
        }
    }
}

#endif

// MARK: - NetworkFiltersView (Response)

extension ConsoleNetworkFiltersView {
    var responseGroup: some View {
        ConsoleFilterSection(
            header: { responseGroupHeader },
            content: { responseGroupContent }
        )
    }

    private var responseGroupHeader: some View {
        ConsoleFilterSectionHeader(
            icon: "arrow.down.circle", title: "Response",
            color: .yellow,
            reset: { viewModel.criteria.response = .default },
            isDefault: viewModel.criteria.response == .default,
            isEnabled: $viewModel.criteria.response.isEnabled
        )
    }

    @ViewBuilder
    private var responseGroupContent: some View {
#if os(iOS) || os(macOS)
        statusCodeRow
        ConsoleFiltersContentTypeCell(selection: $viewModel.criteria.response.contentType.contentType)
        responseSizeRow
        durationRow
#else
        ConsoleFiltersContentTypeCell(selection: $viewModel.criteria.response.contentType.contentType)
#endif
    }

    private var statusCodeRow: some View {
        HStack {
            Text("Status Code")
            Spacer()
            RangePicker(range: $viewModel.criteria.response.statusCode.range)
        }
    }

    private var responseSizeRow: some View {
        HStack {
            Text("Size")
            Spacer()
            FilterPickerMenu(title: viewModel.criteria.response.responseSize.unit.title, width: 50) {
                Picker("Size Unit", selection: $viewModel.criteria.response.responseSize.unit) {
                    ForEach(ConsoleNetworkSearchCriteria.ResponseSizeFilter.MeasurementUnit.allCases) {
                        Text($0.title).tag($0)
                    }
                }.labelsHidden()
            }
            RangePicker(range: $viewModel.criteria.response.responseSize.range)
        }
    }

    private var durationRow: some View {
        HStack {
            Text("Duration")
            Spacer()
            FilterPickerMenu(title: viewModel.criteria.response.duration.unit.title, width: 50) {
                Picker("Unit", selection: $viewModel.criteria.response.duration.unit) {
                    ForEach(ConsoleNetworkSearchCriteria.DurationFilter.Unit.allCases) {
                        Text($0.title).tag($0)
                    }
                }.labelsHidden()
            }
            RangePicker(range: $viewModel.criteria.response.duration.range)
        }
    }
}

// MARK: - NetworkFiltersView (Domains)

extension ConsoleNetworkFiltersView {
    var domainsGroup: some View {
        ConsoleFilterSection(
            header: { domainsGroupHeader },
            content: { domainsGroupContent }
        )
    }

    private var domainsGroupHeader: some View {
        ConsoleFilterSectionHeader(
            icon: "server.rack", title: "Hosts",
            color: .yellow,
            reset: { viewModel.criteria.host = .default },
            isDefault: viewModel.criteria.host == .default,
            isEnabled: $viewModel.criteria.host.isEnabled
        )
    }

    @ViewBuilder
    private var domainsGroupContent: some View {
        makeDomainPicker(limit: 4)
        if viewModel.allDomains.count > 4 {
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
        var domains = viewModel.allDomains
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
        var domains = viewModel.allDomains
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
                viewModel.criteria.host.ignoredHosts = Set(viewModel.allDomains)
            }
            makeDomainPicker()
        }
        .inlineNavigationTitle("Select Hosts")
    }
}

// MARK: - NetworkFiltersView (Networking)

extension ConsoleNetworkFiltersView {
    var networkingGroup: some View {
        ConsoleFilterSection(
            header: { networkingGroupHeader },
            content: { networkingGroupContent }
        )
    }

    private var networkingGroupHeader: some View {
        ConsoleFilterSectionHeader(
            icon: "arrowshape.zigzag.right", title: "Networking",
            color: .yellow,
            reset: { viewModel.criteria.networking = .default },
            isDefault: viewModel.criteria.networking == .default,
            isEnabled: $viewModel.criteria.networking.isEnabled
        )
    }

    @ViewBuilder
    private var networkingGroupContent: some View {
        ConsoleFilters.taskTypePicker($viewModel.criteria.networking.taskType)
        ConsoleFilters.responseSourcePicker($viewModel.criteria.networking.source)
        ConsoleFilters.toggle("Redirect", isOn: $viewModel.criteria.networking.isRedirect)
    }
}

#if DEBUG
struct NetworkFiltersView_Previews: PreviewProvider {
    static var previews: some View {
#if os(macOS)
        ConsoleNetworkFiltersView(viewModel: makeMockViewModel(), sharedCriteriaViewModel: .init(store: .mock))
            .previewLayout(.fixed(width: 320, height: 900))
#else
        NavigationView {
            ConsoleNetworkFiltersView(viewModel: makeMockViewModel(), sharedCriteriaViewModel: .init(store: .mock))
        }.navigationViewStyle(.stack)
#endif
    }
}

private func makeMockViewModel() -> ConsoleNetworkSearchCriteriaViewModel {
    let viewModel = ConsoleNetworkSearchCriteriaViewModel(store: .mock)
    viewModel.mock(domains: [
        "github.com",
        "apple.com",
        "objects-origin.githubusercontent.com",
        "api.github.com",
        "analytics.github.com"
    ])
    return viewModel

}
#endif

// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS) || os(macOS)

// MARK: - NetworkFiltersView (Time Period)

extension NetworkFiltersView {
    var timePeriodGroup: some View {
        FiltersSection(
            isExpanded: $isTimePeriodExpanded,
            header: { timePeriodGroupHeader },
            content: { timePeriodGroupContent }
        )
    }
    
    private var timePeriodGroupHeader: some View {
        FilterSectionHeader(
            icon: "calendar", title: "Time Period",
            color: .yellow,
            reset: { viewModel.criteria.dates = .default },
            isDefault: viewModel.criteria.dates == .default,
            isEnabled: $viewModel.criteria.dates.isEnabled
        )
    }
    
    @ViewBuilder
    private var timePeriodGroupContent: some View {
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


// MARK: - NetworkFiltersView (Duration)

extension NetworkFiltersView {
    @available(iOS 14.0, *)
    var durationGroup: some View {
        FiltersSection(
            isExpanded: $isDurationGroupExpanded,
            header: { durationGroupHeader },
            content: { durationGroupContent }
        )
    }

    private var durationGroupHeader: some View {
        FilterSectionHeader(
            icon: "hourglass", title: "Duration",
            color: .yellow,
            reset: { viewModel.criteria.duration = .default },
            isDefault: viewModel.criteria.duration == .default,
            isEnabled: $viewModel.criteria.duration.isEnabled
        )
    }

#if os(iOS)
    @available(iOS 14.0, *)
    @ViewBuilder
    private var durationGroupContent: some View {
        HStack {
            Text("Duration")
            Spacer()
            durationMinField
            durationMaxField
            Menu(content: { durationUnitPicker }, label: {
                FilterPickerButton(title: viewModel.criteria.duration.unit.localizedTitle)
            })
            .animation(.none)
        }
    }
#elseif os(macOS)
    @ViewBuilder
    private var durationGroupContent: some View {
        HStack {
            durationMinField
            durationMaxField
            durationUnitPicker.fixedSize().labelsHidden()
        }
    }
#endif

    private var durationMinField: some View {
        TextField("Min", text: $viewModel.criteria.duration.min)
            .textFieldStyle(.roundedBorder)
#if os(iOS)
            .keyboardType(.decimalPad)
            .frame(maxWidth: 80)
#endif
    }

    private var durationMaxField: some View {
        TextField("Max", text: $viewModel.criteria.duration.max)
            .textFieldStyle(.roundedBorder)
#if os(iOS)
            .keyboardType(.decimalPad)
            .frame(maxWidth: 80)
#endif
    }

    private var durationUnitPicker: some View {
        Picker("Unit", selection: $viewModel.criteria.duration.unit) {
            Text("Min").tag(NetworkSearchCriteria.DurationFilter.Unit.minutes)
            Text("Sec").tag(NetworkSearchCriteria.DurationFilter.Unit.seconds)
            Text("Ms").tag(NetworkSearchCriteria.DurationFilter.Unit.milliseconds)
        }
    }
}

// MARK: - NetworkFiltersView (Domains)

extension NetworkFiltersView {
    var domainsGroup: some View {
        FiltersSection(
            isExpanded: $isDomainsGroupExpanded,
            header: { domainsGroupHeader },
            content: { domainsGroupContent }
        )
    }

    private var domainsGroupHeader: some View {
        FilterSectionHeader(
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

    #if os(iOS)
    private var domainsShowAllButton: some View {
        NavigationLink(destination: { domainsPickerView}) {
            Text("Show All")
        }
    }

    private func makeDomainPicker(limit: Int? = nil) -> some View {
        var domains = viewModel.allDomains
        if let limit = limit {
            domains = Array(domains.prefix(limit))
        }
        return ForEach(domains, id: \.self) { domain in
            let binding = viewModel.binding(forDomain: domain)
            Button(action: { binding.wrappedValue.toggle() }) {
                HStack {
                    Text(domain)
                        .foregroundColor(.primary)
                    Spacer()
                    Checkbox(isEnabled: binding)
                }
            }
        }
    }
    #elseif os(macOS)
    private var domainsShowAllButton: some View {
        HStack {
            Spacer()
            Button(action: { isDomainsPickerPresented = true }) {
                Text("Show All")
            }
            .padding(.top, 6)
            .popover(isPresented: $isDomainsPickerPresented) {
                domainsPickerView
                    .frame(width: 220, height: 340)
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
            HStack {
                Toggle(domain, isOn: viewModel.binding(forDomain: domain))
                Spacer()
            }
        }
    }
    #endif

    private var domainsPickerView: some View {
        List {
            Button("Deselect All") {
                viewModel.criteria.host.values = []
            }
            makeDomainPicker()
        }
        #if os(iOS)
        .navigationBarTitle("Select Hosts", displayMode: .inline)
        #else
        .navigationTitle("Select Hosts")
        #endif
    }
}

// MARK: - NetworkFiltersView (Networking)

extension NetworkFiltersView {
    var networkingGroup: some View {
        FiltersSection(
            isExpanded: $isRedirectGroupExpanded,
            header: { networkingGroupHeader },
            content: { networkingGroupContent }
        )
    }

    private var networkingGroupHeader: some View {
        FilterSectionHeader(
            icon: "arrowshape.zigzag.right", title: "Networking",
            color: .yellow,
            reset: { viewModel.criteria.networking = .default },
            isDefault: viewModel.criteria.networking == .default,
            isEnabled: $viewModel.criteria.networking.isEnabled
        )
    }

    @ViewBuilder
    private var networkingGroupContent: some View {
        Filters.taskTypePicker($viewModel.criteria.networking.taskType)
        Filters.responseSourcePicker($viewModel.criteria.networking.source)
        Filters.toggle("Redirect", isOn: $viewModel.criteria.networking.isRedirect)
    }
}

// MARK: - Helpers

private struct FiltersSection<Header: View, Content: View>: View {
    var isExpanded: Binding<Bool>
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    var body: some View {
#if os(iOS)
        Section(content: content, header: header)
#elseif os(macOS)
        DisclosureGroup(
            isExpanded: isExpanded,
            content: {
                VStack {
                    content()
                }
                .padding(.leading, 12)
                .padding(.trailing, 5)
                .padding(.top, Filters.contentTopInset)
            },
            label: header
        )
#endif
    }
}

private extension Filters {
    static func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
#if os(iOS)
        Toggle(title, isOn: isOn)
        #elseif os(macOS)
        HStack {
            Toggle(title, isOn: isOn)
            Spacer()
        }
        #endif
    }
}

#endif

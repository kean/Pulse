// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(macOS)

struct NetworkFiltersView: View {
    @ObservedObject var viewModel: NetworkSearchCriteriaViewModel

    @AppStorage("networkFilterIsParametersExpanded") private var isParametersExpanded = true
    @AppStorage("networkFilterIsResponseExpanded") private var isResponseGroupExpanded = true
    @AppStorage("networkFilterIsTimePeriodExpanded") private var isTimePeriodExpanded = true
    @AppStorage("networkFilterIsDomainsGroupExpanded") private var isDomainsGroupExpanded = true
    @AppStorage("networkFilterIsDurationGroupExpanded") private var isDurationGroupExpanded = true
    @AppStorage("networkFilterIsContentTypeGroupExpanded") private var isContentTypeGroupExpanded = true
    @AppStorage("networkFilterIsRedirectGroupExpanded") private var isRedirectGroupExpanded = true

    @State private var isDomainsPickerPresented = false

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
                
                generalGroup
                responseGroup
                durationGroup
                timePeriodGroup
                domainsGroup
                networkingGroup
            }.padding(Filters.formPadding)
        }
    }

    // MARK: - General
    
    private var generalGroup: some View {
        DisclosureGroup(isExpanded: $isParametersExpanded, content: {
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

    // MARK: - Response
    
    private var responseGroup: some View {
        DisclosureGroup(isExpanded: $isResponseGroupExpanded, content: {
            FiltersSection {
                statusCodeRow
                contentTypeRow
                responseSizeRow
            }
        }, label: {
            FilterSectionHeader(
                icon: "arrow.down.circle", title: "Response",
                color: .yellow,
                reset: { viewModel.criteria.response = .default },
                isDefault: viewModel.criteria.response == .default,
                isEnabled: $viewModel.criteria.response.isEnabled
            )
        })
    }

    @ViewBuilder
    private var statusCodeRow: some View {
        HStack {
            Text("Status Code")
                .fixedSize()

            TextField("Min", text: $viewModel.criteria.response.statusCode.from)
            .textFieldStyle(.roundedBorder)

            TextField("Max", text: $viewModel.criteria.response.statusCode.to)
            .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var contentTypeRow: some View {
        HStack {
            Text("Content Type")
            Spacer()
            Filters.contentTypesPicker(selection: $viewModel.criteria.response.contentType.contentType)
                .labelsHidden()
                .fixedSize()
        }
    }

    @ViewBuilder
    private var responseSizeRow: some View {
        HStack {
            TextField("Min", text: $viewModel.criteria.response.responseSize.from)
            .textFieldStyle(.roundedBorder)

            TextField("Max", text: $viewModel.criteria.response.responseSize.to)
            .textFieldStyle(.roundedBorder)

            Filters.sizeUnitPicker($viewModel.criteria.response.responseSize.unit)
                .labelsHidden()
        }
    }

    // MARK: - Time Period Group

    private var timePeriodGroup: some View {
        DisclosureGroup(isExpanded: $isTimePeriodExpanded, content: {
            FiltersSection {
                HStack {
                    Toggle("Latest Session", isOn: $viewModel.criteria.dates.isCurrentSessionOnly)
                    Spacer()
                }
                startDateRow
                endDateRow
                HStack {
                    Button("Recent") {
                        viewModel.criteria.dates = .recent
                    }
                    Button("Today") {
                        viewModel.criteria.dates = .today
                    }
                    Spacer()
                }.padding(.top, 6)
            }
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

    @ViewBuilder
    private var startDateRow: some View {
        let fromBinding = Binding(get: {
            viewModel.criteria.dates.startDate ?? Date().addingTimeInterval(-3600)
        }, set: { newValue in
            viewModel.criteria.dates.startDate = newValue
        })

        VStack(spacing: 5) {
            HStack {
                Toggle("Start Date", isOn: $viewModel.criteria.dates.isStartDateEnabled)
                Spacer()
            }
            DatePicker("Start Date", selection: fromBinding)
                .disabled(!viewModel.criteria.dates.isStartDateEnabled)
                .fixedSize()
                .labelsHidden()
        }
    }

    @ViewBuilder
    private var endDateRow: some View {
        let toBinding = Binding(get: {
            viewModel.criteria.dates.endDate ?? Date()
        }, set: { newValue in
            viewModel.criteria.dates.endDate = newValue
        })

        VStack(spacing: 5) {
            HStack {
                Toggle("End Date", isOn: $viewModel.criteria.dates.isEndDateEnabled)
                Spacer()
            }
            DatePicker("End Date", selection: toBinding)
                .disabled(!viewModel.criteria.dates.isEndDateEnabled)
                .fixedSize()
                .labelsHidden()
        }
    }

    // MARK: - Domains Group

    private var domainsGroup: some View {
        DisclosureGroup(isExpanded: $isDomainsGroupExpanded, content: {
            FiltersSection {
                makeDomainPicker(limit: 4)
                if viewModel.allDomains.count > 4 {
                    domainsShowAllButton
                }
            }
        }, label: {
            FilterSectionHeader(
                icon: "server.rack", title: "Hosts",
                color: .yellow,
                reset: { viewModel.criteria.host = .default },
                isDefault: viewModel.criteria.host == .default,
                isEnabled: $viewModel.criteria.host.isEnabled
            )
        })
    }

    private var domainsShowAllButton: some View {
        HStack {
            Spacer()
            Button(action: { isDomainsPickerPresented = true }) {
                Text("Show All")
            }
            .padding(.top, 6)
            .popover(isPresented: $isDomainsPickerPresented) {
                List {
                    Button("Deselect All") {
                        viewModel.criteria.host.values = []
                    }
                    makeDomainPicker()
                        .padding(.leading, -13) // Compensate Filers.toggle inset
                }
                .frame(width: 220, height: 340)
                .navigationTitle("Select Hosts")
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
    
    private var durationGroup: some View {
        DisclosureGroup(isExpanded: $isDurationGroupExpanded, content: {
            FiltersSection {
                durationRow
            }
        }, label: {
            FilterSectionHeader(
                icon: "hourglass", title: "Duration",
                color: .yellow,
                reset: { viewModel.criteria.duration = .default },
                isDefault: viewModel.criteria.duration == .default,
                isEnabled: $viewModel.criteria.duration.isEnabled
            )
        })
    }

    @ViewBuilder
    private var durationRow: some View {
        HStack {
            TextField("Min", text: $viewModel.criteria.duration.min)
            .textFieldStyle(.roundedBorder)

            TextField("Max", text: $viewModel.criteria.duration.max)
            .textFieldStyle(.roundedBorder)

            Picker("Unit", selection: $viewModel.criteria.duration.unit) {
                Text("min").tag(NetworkSearchCriteria.DurationFilter.Unit.minutes)
                Text("sec").tag(NetworkSearchCriteria.DurationFilter.Unit.seconds)
                Text("ms").tag(NetworkSearchCriteria.DurationFilter.Unit.milliseconds)
            }
            .fixedSize()
            .labelsHidden()
        }
    }

    private var networkingGroup: some View {
        DisclosureGroup(isExpanded: $isRedirectGroupExpanded, content: {
            FiltersSection {
                HStack {
                    Text("Source")
                    Spacer()
                    Filters.responseSourcePicker($viewModel.criteria.networking.source)
                        .fixedSize()
                        .labelsHidden()
                }
                HStack {
                    Toggle("Redirect", isOn: $viewModel.criteria.networking.isRedirect)
                    Spacer()
                }
            }
        }, label: {
            FilterSectionHeader(
                icon: "arrowshape.zigzag.right", title: "Networking",
                color: .yellow,
                reset: { viewModel.criteria.networking = .default },
                isDefault: viewModel.criteria.networking == .default,
                isEnabled: $viewModel.criteria.networking.isEnabled
            )
        })
    }
    
    private typealias ContentType = NetworkSearchCriteria.ContentTypeFilter.ContentType
}

private struct CustomFilterView: View {
    @ObservedObject var filter: NetworkSearchFilter
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
                Text("URL").tag(NetworkSearchFilter.Field.url)
                Text("Host").tag(NetworkSearchFilter.Field.host)
                Text("Method").tag(NetworkSearchFilter.Field.method)
                Text("Status Code").tag(NetworkSearchFilter.Field.statusCode)
                Text("Error Code").tag(NetworkSearchFilter.Field.errorCode)
            }
            Section {
                Text("Request Headers").tag(NetworkSearchFilter.Field.requestHeader)
                Text("Response Headers").tag(NetworkSearchFilter.Field.responseHeader)
            }
            Section {
                Text("Request Body").tag(NetworkSearchFilter.Field.requestBody)
                Text("Response Body").tag(NetworkSearchFilter.Field.responseBody)
            }
        }.frame(width: 130)
    }
    
    private var matchPicker: some View {
        Picker("", selection: $filter.match) {
            Section {
                Text("Contains").tag(NetworkSearchFilter.Match.contains)
                Text("Not Contains").tag(NetworkSearchFilter.Match.notContains)
            }
            Section {
                Text("Equals").tag(NetworkSearchFilter.Match.equal)
                Text("Not Equals").tag(NetworkSearchFilter.Match.notEqual)
            }
            Section {
                Text("Begins With").tag(NetworkSearchFilter.Match.beginsWith)
            }
            Section {
                Text("Regex").tag(NetworkSearchFilter.Match.regex)
            }
        }.frame(width: 130)
    }
}

#if DEBUG
struct NetworkFiltersPanelPro_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NetworkFiltersView(viewModel: makeMockViewModel())
                .previewLayout(.fixed(width: Filters.preferredWidth - 15, height: 900))
        }
    }
}

private func makeMockViewModel() -> NetworkSearchCriteriaViewModel {
    let viewModel = NetworkSearchCriteriaViewModel()
    viewModel.setInitialDomains(["api.github.com", "github.com", "apple.com", "google.com", "example.com"])
    return viewModel

}
#endif

#endif

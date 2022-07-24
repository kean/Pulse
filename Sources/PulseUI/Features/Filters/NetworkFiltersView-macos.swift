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
                timePeriodGroup
                domainsGroup
                durationGroup
                redirectGroup
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
                reset:  {
                    viewModel.criteria.statusCode = .default
                    viewModel.criteria.contentType = .default
                    viewModel.criteria.responseSize = .default
                },
                isDefault: viewModel.criteria.statusCode == .default &&
                viewModel.criteria.contentType == .default &&
                viewModel.criteria.responseSize == .default,
                isEnabled: Binding(get: {
                    viewModel.criteria.statusCode.isEnabled ||
                    viewModel.criteria.contentType.isEnabled ||
                    viewModel.criteria.responseSize.isEnabled
                }, set: {
                    viewModel.criteria.statusCode.isEnabled = $0
                    viewModel.criteria.contentType.isEnabled = $0
                    viewModel.criteria.responseSize.isEnabled = $0
                })

            )
        })
    }

    @ViewBuilder
    private var statusCodeRow: some View {
        HStack {
            Text("Status Code")
                .fixedSize()

            TextField("Min", text: $viewModel.criteria.statusCode.from, onEditingChanged: {
                if $0 { viewModel.criteria.statusCode.isEnabled = true }
            })
            .textFieldStyle(.roundedBorder)

            TextField("Max", text: $viewModel.criteria.statusCode.to, onEditingChanged: {
                if $0 { viewModel.criteria.statusCode.isEnabled = true }
            })
            .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var contentTypeRow: some View {
        HStack {
            Text("Content Type")
            Spacer()
            Filters.contentTypesPicker(selection: $viewModel.criteria.contentType.contentType)
                .labelsHidden()
                .fixedSize()
        }
    }

    @ViewBuilder
    private var responseSizeRow: some View {
        HStack {
            Text("Size")

            TextField("Min", text: $viewModel.criteria.responseSize.from, onEditingChanged: {
                if $0 { viewModel.criteria.responseSize.isEnabled = true }
            })
            .textFieldStyle(.roundedBorder)

            TextField("Max", text: $viewModel.criteria.responseSize.to, onEditingChanged: {
                if $0 { viewModel.criteria.responseSize.isEnabled = true }
            })
            .textFieldStyle(.roundedBorder)

            Filters.sizeUnitPicker($viewModel.criteria.responseSize.unit)
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
                }
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
            VStack {
                makeDomainPicker(limit: 4)
                if viewModel.allDomains.count > 4 {
                    HStack {
                        Button(action: { isDomainsPickerPresented = true }) {
                            Text("Show All")
                        }
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
                    }.padding(.leading, 13)
                }
            }.padding(.top, Filters.contentTopInset)
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

    private func makeDomainPicker(limit: Int? = nil) -> some View {
        var domains = viewModel.allDomains
        if let limit = limit {
            domains = Array(domains.prefix(limit))
        }
        return ForEach(domains, id: \.self) { domain in
            Filters.toggle(domain, isOn: viewModel.binding(forDomain: domain))
        }
    }
    
    private var durationGroup: some View {
        DisclosureGroup(isExpanded: $isDurationGroupExpanded, content: {
            VStack(spacing: 6) {
                DurationPicker(title: "Min", value: $viewModel.criteria.duration.from)
                DurationPicker(title: "Max", value: $viewModel.criteria.duration.to)
            }.padding(.top, Filters.contentTopInset)
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

    private var redirectGroup: some View {
        DisclosureGroup(isExpanded: $isRedirectGroupExpanded, content: {
            Filters.toggle("One or More Redirect", isOn: $viewModel.criteria.redirect.isRedirect)
                .padding(.top, Filters.contentTopInset)
        }, label: {
            FilterSectionHeader(
                icon: "arrowshape.zigzag.right", title: "Redirect",
                color: .yellow,
                reset: { viewModel.criteria.redirect = .default },
                isDefault: viewModel.criteria.redirect == .default,
                isEnabled: $viewModel.criteria.redirect.isEnabled
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
        }.frame(width: 135)
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
        }.frame(width: 135)
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

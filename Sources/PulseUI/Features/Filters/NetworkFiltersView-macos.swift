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
    @AppStorage("networkFilterIsStatusCodeExpanded") private var isStatusCodeExpanded = true
    @AppStorage("networkFilterIsTimePeriodExpanded") private var isTimePeriodExpanded = true
    @AppStorage("networkFilterIsDomainsGroupExpanded") private var isDomainsGroupExpanded = true
    @AppStorage("networkFilterIsDurationGroupExpanded") private var isDurationGroupExpanded = true
    @AppStorage("networkFilterIsContentTypeGroupExpanded") private var isContentTypeGroupExpanded = true
    @AppStorage("networkFilterIsRedirectGroupExpanded") private var isRedirectGroupExpanded = true

    
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
                statusCode
                contentTypeGroup
                timePeriodGroup
                domainsGroup
                durationGroup
                redirectGroup
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
    
    private var statusCode: some View {
        DisclosureGroup(isExpanded: $isStatusCodeExpanded, content: {
            HStack {
                Text("Range:")
                    .foregroundColor(.secondary)
                TextField("From", text: $viewModel.criteria.statusCode.from, onEditingChanged: {
                    if $0 { viewModel.criteria.statusCode.isEnabled = true }
                })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 52)
                TextField("To", text: $viewModel.criteria.statusCode.to, onEditingChanged: {
                    if $0 { viewModel.criteria.statusCode.isEnabled = true }
                })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 49)
            }.padding(EdgeInsets(top: Filters.contentTopInset, leading: 8, bottom: 4, trailing: 6))
        }, label: {
            FilterSectionHeader(
                icon: "number", title: "Status Code",
                color: .yellow,
                reset:  { viewModel.criteria.statusCode = .default },
                isDefault: viewModel.criteria.statusCode == .default,
                isEnabled: $viewModel.criteria.statusCode.isEnabled
            )
        })
    }
    
    private var timePeriodGroup: some View {
        DisclosureGroup(isExpanded: $isTimePeriodExpanded, content: {
            Filters.toggle("Latest Session", isOn: $viewModel.criteria.dates.isCurrentSessionOnly)
                .padding(.top, Filters.contentTopInset)
                        
            let fromBinding = Binding(get: {
                viewModel.criteria.dates.startDate ?? Date().addingTimeInterval(-3600)
            }, set: { newValue in
                viewModel.criteria.dates.startDate = newValue
            })
            
            let toBinding = Binding(get: {
                viewModel.criteria.dates.endDate ?? Date()
            }, set: { newValue in
                viewModel.criteria.dates.endDate = newValue
            })
            
            Filters.toggle("Start Date", isOn: $viewModel.criteria.dates.isStartDateEnabled)
            HStack(spacing: 0) {
                DatePicker("", selection: fromBinding)
                    .disabled(!viewModel.criteria.dates.isStartDateEnabled)
                    .fixedSize()
                Spacer()
            }

            Filters.toggle("End Date", isOn: $viewModel.criteria.dates.isEndDateEnabled)
            HStack(spacing: 0) {
                DatePicker("", selection: toBinding)
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
    
    private var domainsGroup: some View {
        DisclosureGroup(isExpanded: $isDomainsGroupExpanded, content: {
            Picker("", selection: $viewModel.criteria.host.value) {
                Text("Any").tag("")
                ForEach(viewModel.allDomains, id: \.self) {
                    Text($0).tag($0)
                }
            }.padding(.top, Filters.contentTopInset)
        }, label: {
            FilterSectionHeader(
                icon: "server.rack", title: "Host",
                color: .yellow,
                reset: { viewModel.criteria.host = .default },
                isDefault: viewModel.criteria.host == .default,
                isEnabled: $viewModel.criteria.host.isEnabled
            )
        })
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
    
    private var contentTypeGroup: some View {
        DisclosureGroup(isExpanded: $isContentTypeGroupExpanded, content: {
            VStack(spacing: 6) {
                Filters.contentTypesPicker(selection: $viewModel.criteria.contentType.contentType)
                    .labelsHidden()
            }.padding(.top, Filters.contentTopInset)
        }, label: {
            FilterSectionHeader(
                icon: "doc", title: "Content Type",
                color: .yellow,
                reset: { viewModel.criteria.contentType = .default },
                isDefault: viewModel.criteria.contentType == .default,
                isEnabled: $viewModel.criteria.contentType.isEnabled
            )
        })
    }
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
        }.frame(width: 120)
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
        }.frame(width: 120)
    }
}

#if DEBUG
struct NetworkFiltersPanelPro_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NetworkFiltersView(viewModel: .init())
                .previewLayout(.fixed(width: 175, height: 800))
        }
    }
}
#endif

#endif

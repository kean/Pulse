// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS)

struct NetworkFiltersView: View {
    @ObservedObject var viewModel: NetworkSearchCriteriaViewModel

    @State var isParametersExpanded = true
    @State var isResponseGroupExpanded = true
    @State var isTimePeriodExpanded = true
    @State var isDomainsGroupExpanded = true
    @State var isDurationGroupExpanded = true
    @State var isContentTypeGroupExpanded = true
    @State var isRedirectGroupExpanded = true

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
                    generalGroup
                }
            }

            Section(header: FilterSectionHeader(
                icon: "arrow.down.circle", title: "Response",
                color: .yellow,
                reset: { viewModel.criteria.response = .default },
                isDefault: viewModel.criteria.response == .default
            )) {
                responseGroup
            }

            if #available(iOS 14.0, *) {
                durationGroup
            }

            Section(header: FilterSectionHeader(
                icon: "calendar", title: "Time Period",
                color: .yellow,
                reset: { viewModel.criteria.dates = .default },
                isDefault: viewModel.criteria.dates == .default
            )) {
                timePeriodGroup
            }

            domainsGroup
            networkingGroup
        }
        .navigationBarTitle("Filters", displayMode: .inline)
        .navigationBarItems(leading: buttonClose, trailing: buttonReset)
    }

    private var buttonClose: some View {
        Button("Close") { isPresented = false }
    }

    private var buttonReset: some View {
        Button("Reset") { viewModel.resetAll() }
            .disabled(!viewModel.isButtonResetEnabled)
    }

    // MARK: - General

    @available(iOS 14.0, *)
    @ViewBuilder
    private var generalGroup: some View {
        ForEach(viewModel.filters) { filter in
            CustomNetworkFilterView(filter: filter, onRemove: {
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

    // MARK: - Response

    @ViewBuilder
    private var responseGroup: some View {
        HStack {
            makeRangePicker(title: "Status Code", from: $viewModel.criteria.response.statusCode.from, to: $viewModel.criteria.response.statusCode.to, isEnabled: $viewModel.criteria.response.isEnabled)
        }
        Filters.contentTypesPicker(selection: $viewModel.criteria.response.contentType.contentType)
        HStack {
            makeRangePicker(title: "Size", from: $viewModel.criteria.response.responseSize.from, to: $viewModel.criteria.response.responseSize.to, isEnabled: $viewModel.criteria.response.isEnabled)
            if #available(iOS 14.0, *) {
                Menu(content: {
                    Filters.sizeUnitPicker($viewModel.criteria.response.responseSize.unit).labelsHidden()
                }, label: {
                    FilterPickerButton(title: viewModel.criteria.response.responseSize.unit.localizedTitle)
                })
                .animation(.none)
                .fixedSize()
            } else {
                Text("KB")
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func makeRangePicker(title: String, from: Binding<String>, to: Binding<String>, isEnabled: Binding<Bool>) -> some View {
        Text(title)
        Spacer()
        TextField("Min", text: from, onEditingChanged: {
            if $0 { isEnabled.wrappedValue = true }
        })
        .keyboardType(.decimalPad)
        .textFieldStyle(.roundedBorder)
        .frame(width: 80)
        TextField("Max", text: to, onEditingChanged: {
            if $0 { isEnabled.wrappedValue = true }
        })
        .keyboardType(.decimalPad)
        .textFieldStyle(.roundedBorder)
        .frame(width: 80)
    }

    // MARK: - Time Period Group

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

struct NetworkFiltersView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                NetworkFiltersView(viewModel: .init(), isPresented: .constant(true))
            }
        }
    }
}

#endif

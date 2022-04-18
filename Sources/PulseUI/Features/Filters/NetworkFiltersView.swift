// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS)

@available(iOS 13.0, *)
struct NetworkFiltersView: View {
    @ObservedObject var viewModel: NetworkSearchCriteriaViewModel

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
        }
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
}

@available(iOS 14.0, *)
private struct CustomNetworkFilterView: View {
    @ObservedObject var filter: NetworkSearchFilter
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
                // Splitting this because of the generics limitation
                basicFields
                Divider()
                advancedFields
            }
        }, label: {
            FilterPickerButton(title: filter.field.localizedTitle)
        }).animation(.none)
    }

    @ViewBuilder
    private var basicFields: some View {
        Text("URL").tag(NetworkSearchFilter.Field.url)
        Text("Host").tag(NetworkSearchFilter.Field.host)
        Text("Method").tag(NetworkSearchFilter.Field.method)
        Text("Status Code").tag(NetworkSearchFilter.Field.statusCode)
        Text("Error Code").tag(NetworkSearchFilter.Field.errorCode)
    }

    @ViewBuilder
    private var advancedFields: some View {
        Text("Request Headers").tag(NetworkSearchFilter.Field.requestHeader)
        Text("Response Headers").tag(NetworkSearchFilter.Field.responseHeader)
        Divider()
        Text("Request Body").tag(NetworkSearchFilter.Field.requestBody)
        Text("Response Body").tag(NetworkSearchFilter.Field.responseBody)
    }

    private var matchPicker: some View {
        Menu(content: {
            Picker("", selection: $filter.match) {
                Text("Contains").tag(NetworkSearchFilter.Match.contains)
                Text("Not Contains").tag(NetworkSearchFilter.Match.notContains)
                Divider()
                Text("Equals").tag(NetworkSearchFilter.Match.equal)
                Text("Not Equals").tag(NetworkSearchFilter.Match.notEqual)
                Divider()
                Text("Begins With").tag(NetworkSearchFilter.Match.beginsWith)
                Divider()
                Text("Regex").tag(NetworkSearchFilter.Match.regex)
            }
        }, label: {
            FilterPickerButton(title: filter.match.localizedTitle)
        }).animation(.none)
    }
}

@available(iOS 13.0, *)
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

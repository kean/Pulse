// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS) || os(macOS)

@available(iOS 15, *)
struct ConsoleCustomNetworkFilterView: View {
    @ObservedObject var filter: NetworkSearchFilter
    let onRemove: (() -> Void)?

    var body: some View {
        ConsoleCustomFilterView(text: $filter.value, onRemove: onRemove, pickers: {
            fieldMenu
            matchMenu
        })
    }

    private var fieldMenu: some View {
        FilterPickerMenu(title: filter.field.localizedTitle) {
            Picker("", selection: $filter.field) {
                fieldPickerBasicSection
                Divider()
                fieldPickerAdvancedSection
            }
        }
    }
    
    private var matchMenu: some View {
        FilterPickerMenu(title: filter.match.localizedTitle) { matchPicker }
    }

    @ViewBuilder
    private var fieldPicker: some View {
        Picker("Field", selection: $filter.field) {
            fieldPickerBasicSection
            Divider()
            fieldPickerAdvancedSection
        }.labelsHidden()
    }

    @ViewBuilder
    private var fieldPickerBasicSection: some View {
        Text("URL").tag(NetworkSearchFilter.Field.url)
        Text("Host").tag(NetworkSearchFilter.Field.host)
        Text("Method").tag(NetworkSearchFilter.Field.method)
        Text("Status Code").tag(NetworkSearchFilter.Field.statusCode)
        Text("Error Code").tag(NetworkSearchFilter.Field.errorCode)
    }

    @ViewBuilder
    private var fieldPickerAdvancedSection: some View {
        Text("Request Headers").tag(NetworkSearchFilter.Field.requestHeader)
        Text("Response Headers").tag(NetworkSearchFilter.Field.responseHeader)
        Divider()
        Text("Request Body").tag(NetworkSearchFilter.Field.requestBody)
        Text("Response Body").tag(NetworkSearchFilter.Field.responseBody)
    }

    private var matchPicker: some View {
        Picker("Matching", selection: $filter.match) {
            Text("Contains").tag(NetworkSearchFilter.Match.contains)
            Text("Not Contains").tag(NetworkSearchFilter.Match.notContains)
            Divider()
            Text("Equals").tag(NetworkSearchFilter.Match.equal)
            Text("Not Equals").tag(NetworkSearchFilter.Match.notEqual)
            Divider()
            Text("Begins With").tag(NetworkSearchFilter.Match.beginsWith)
            Divider()
            Text("Regex").tag(NetworkSearchFilter.Match.regex)
        }.labelsHidden()
    }
}

#endif

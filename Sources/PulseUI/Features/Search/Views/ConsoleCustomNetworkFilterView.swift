// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS) || os(macOS)

@available(iOS 15, *)
struct ConsoleCustomNetworkFilterView: View {
    @Binding var filter: ConsoleCustomNetworkFilter
    let onRemove: (() -> Void)?

    var body: some View {
        ConsoleCustomFilterView(text: $filter.value, onRemove: onRemove, pickers: {
            fieldMenu
#if os(macOS)
                .frame(width: 60)
#endif
            matchMenu
        })
    }

    private var fieldMenu: some View {
        ConsoleSearchInlinePickerMenu(title: filter.field.localizedTitle) {
            Picker("Field", selection: $filter.field) {
                fieldPickerBasicSection
                Divider()
                fieldPickerAdvancedSection
            }.labelsHidden()
        }
    }
    
    private var matchMenu: some View {
        ConsoleSearchInlinePickerMenu(title: filter.match.localizedTitle) { matchPicker }
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
        Text("URL").tag(ConsoleCustomNetworkFilter.Field.url)
        Text("Host").tag(ConsoleCustomNetworkFilter.Field.host)
        Text("Method").tag(ConsoleCustomNetworkFilter.Field.method)
        Text("Status Code").tag(ConsoleCustomNetworkFilter.Field.statusCode)
        Text("Error Code").tag(ConsoleCustomNetworkFilter.Field.errorCode)
    }

    @ViewBuilder
    private var fieldPickerAdvancedSection: some View {
        Text("Request Headers").tag(ConsoleCustomNetworkFilter.Field.requestHeader)
        Text("Response Headers").tag(ConsoleCustomNetworkFilter.Field.responseHeader)

        // TODO: re-enable when fixed
//        Divider()
//        Text("Request Body").tag(ConsoleCustomNetworkFilter.Field.requestBody)
//        Text("Response Body").tag(ConsoleCustomNetworkFilter.Field.responseBody)
    }

    private var matchPicker: some View {
        Picker("Matching", selection: $filter.match) {
            Text("Contains").tag(ConsoleCustomNetworkFilter.Match.contains)
            Text("Not Contains").tag(ConsoleCustomNetworkFilter.Match.notContains)
            Divider()
            Text("Equals").tag(ConsoleCustomNetworkFilter.Match.equal)
            Text("Not Equals").tag(ConsoleCustomNetworkFilter.Match.notEqual)
            Divider()
            Text("Begins With").tag(ConsoleCustomNetworkFilter.Match.beginsWith)
            Divider()
            Text("Regex").tag(ConsoleCustomNetworkFilter.Match.regex)
        }.labelsHidden()
    }
}

#endif

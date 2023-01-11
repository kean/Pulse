// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS) || os(macOS)

@available(iOS 15, *)
struct ConsoleCustomNetworkFilterView: View {
    @ObservedObject var filter: NetworkSearchFilter
    let onRemove: (NetworkSearchFilter) -> Void
    let isRemoveHidden: Bool

    @State private var textFieldValue: String

    init(filter: NetworkSearchFilter, onRemove: @escaping (NetworkSearchFilter) -> Void, isRemoveHidden: Bool) {
        self.filter = filter
        self.textFieldValue = filter.value
        self.onRemove = onRemove
        self.isRemoveHidden = isRemoveHidden
    }

    @FocusState private var isTextFieldFocused: Bool
    @State private var isEditing = false

    var body: some View {
        HStack(spacing: 8) {
            if !isEditing {
                fieldMenu.lineLimit(1).layoutPriority(1)
                matchMenu.lineLimit(1).layoutPriority(1)
            }
            TextField("Value", text: $textFieldValue)
                .onSubmit {
                    filter.value = textFieldValue
                }
                .focused($isTextFieldFocused)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
#if os(iOS)
                .autocapitalization(.none)
#endif
#if os(macOS)
                .frame(minWidth: 100)
#endif
                .onChange(of: isTextFieldFocused) { isTextFieldFocused in
                    withAnimation { isEditing = isTextFieldFocused }
                }
            if !isEditing {
                if !isRemoveHidden {
                    Button(action: { onRemove(filter) }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .padding(.leading, 6)
                }
            } else {
                Button("Done") {
                    filter.value = textFieldValue
                    isTextFieldFocused = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }
        }
#if os(iOS)
        .padding(EdgeInsets(top: 2, leading: -6, bottom: 2, trailing: -8))
#endif
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

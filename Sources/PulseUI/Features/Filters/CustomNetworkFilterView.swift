// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS) || os(macOS)

@available(iOS 15, *)
struct CustomNetworkFilterView: View {
    @ObservedObject var filter: NetworkSearchFilter
    let onRemove: (NetworkSearchFilter) -> Void
    let isRemoveHidden: Bool
#if os(iOS)
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var isEditing = false

    var body: some View {
        HStack(spacing: 8) {
            if !isEditing {
                fieldMenu.lineLimit(1).layoutPriority(1)
                matchMenu.lineLimit(1).layoutPriority(1)
            }
            TextField("Value", text: $filter.value)
                .focused($isTextFieldFocused)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
                .autocapitalization(.none)
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
                Button("Done") { isTextFieldFocused = false }.foregroundColor(.blue)
            }
        }
        .padding(EdgeInsets(top: 2, leading: -4, bottom: 2, trailing: -8))
    }
    
    private var fieldMenu: some View {
        Menu(content: {
            Picker("", selection: $filter.field) {
                fieldPickerBasicSection
                Divider()
                fieldPickerAdvancedSection
            }
        }, label: {
            FilterPickerButton(title: filter.field.localizedTitle)
        }).animation(.none)
    }
    
    private var matchMenu: some View {
        Menu(content: {
            matchPicker
        }, label: {
            FilterPickerButton(title: filter.match.localizedTitle)
        }).animation(.none)
    }
    
#else
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                fieldPicker.frame(width: 140)
                Spacer()
                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .foregroundColor(Color.red)
            }
            HStack {
                matchPicker.frame(width: 140)
                Spacer()
            }
            HStack {
                TextField("Value", text: $filter.value)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(EdgeInsets(top: 8, leading: 6, bottom: 8, trailing: 6))
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }

#endif

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

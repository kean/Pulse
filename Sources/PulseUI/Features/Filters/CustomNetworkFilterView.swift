// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS) || os(macOS)

@available(iOS 14.0, *)
struct CustomNetworkFilterView: View {
    @ObservedObject var filter: NetworkSearchFilter
    let onRemove: () -> Void
    
#if os(iOS)
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                fieldMenu
                Spacer().frame(width: 8)
                matchMenu
                Spacer(minLength: 0)
                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
                .foregroundColor(Color.red)
            }
            TextField("Value", text: $filter.value)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
                .autocapitalization(.none)
        }
        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 4))
        .cornerRadius(8)
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

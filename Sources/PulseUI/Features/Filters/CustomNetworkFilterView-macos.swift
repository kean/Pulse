// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(macOS)

struct CustomNetworkFilterView: View {
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

#endif

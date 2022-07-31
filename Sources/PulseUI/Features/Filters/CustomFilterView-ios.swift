// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS)

@available(iOS 14.0, *)
struct CustomFilterView: View {
    @ObservedObject var filter: ConsoleSearchFilter
    let onRemove: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                fieldPicker
                Spacer().frame(width: 8)
                matchPicker
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

    @ViewBuilder
    private var fieldPicker: some View {
        Menu(content: {
            Picker("", selection: $filter.field) {
                Text("Level").tag(ConsoleSearchFilter.Field.level)
                Text("Label").tag(ConsoleSearchFilter.Field.label)
                Text("Message").tag(ConsoleSearchFilter.Field.message)
                Divider()
                Text("Metadata").tag(ConsoleSearchFilter.Field.metadata)
                Divider()
                Text("File").tag(ConsoleSearchFilter.Field.file)
                Text("Function").tag(ConsoleSearchFilter.Field.function)
                Text("Line").tag(ConsoleSearchFilter.Field.line)
            }
        }, label: {
            FilterPickerButton(title: filter.field.localizedTitle)
        }).animation(.none)
    }

    private var matchPicker: some View {
        Menu(content: {
            Picker("", selection: $filter.match) {
                Text("Contains").tag(ConsoleSearchFilter.Match.contains)
                Text("Not Contains").tag(ConsoleSearchFilter.Match.notContains)
                Divider()
                Text("Equals").tag(ConsoleSearchFilter.Match.equal)
                Text("Not Equals").tag(ConsoleSearchFilter.Match.notEqual)
                Divider()
                Text("Begins With").tag(ConsoleSearchFilter.Match.beginsWith)
                Divider()
                Text("Regex").tag(ConsoleSearchFilter.Match.regex)
            }
        }, label: {
            FilterPickerButton(title: filter.match.localizedTitle)
        }).animation(.none)
    }
}

#endif

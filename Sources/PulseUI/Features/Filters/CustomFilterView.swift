// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS) || os(macOS)

@available(iOS 14.0, *)
struct CustomFilterView: View {
    @ObservedObject var filter: ConsoleSearchFilter
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
                .foregroundColor(.red)
            }
            TextField("Value", text: $filter.value)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
                .autocapitalization(.none)
        }
        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 4))
        .cornerRadius(8)
    }

    // TODO: On iOS 16, inline picker looks OK
    private var fieldMenu: some View {
        Menu(content: {
            fieldPicker
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
                fieldPicker
                    .frame(width: 140)
                Spacer()
                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
            HStack {
                matchPicker
                    .frame(width: 140)
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

    private var fieldPicker: some View {
        Picker("Field", selection: $filter.field) {
            Text("Level").tag(ConsoleSearchFilter.Field.level)
            Text("Label").tag(ConsoleSearchFilter.Field.label)
            Text("Message").tag(ConsoleSearchFilter.Field.message)
            Divider()
            Text("Metadata").tag(ConsoleSearchFilter.Field.metadata)
            Divider()
            Text("File").tag(ConsoleSearchFilter.Field.file)
        }
        .labelsHidden()
    }

    private var matchPicker: some View {
        Picker("Match", selection: $filter.match) {
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
        .labelsHidden()
    }
}

#endif

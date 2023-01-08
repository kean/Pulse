// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS) || os(macOS)

@available(iOS 15, *)
struct CustomFilterView: View {
    @ObservedObject var filter: ConsoleSearchFilter
    let onRemove: (ConsoleSearchFilter) -> Void
    let isRemoveHidden: Bool

    @State private var textFieldValue: String

    init(filter: ConsoleSearchFilter, onRemove: @escaping (ConsoleSearchFilter) -> Void, isRemoveHidden: Bool) {
        self.filter = filter
        self.textFieldValue = filter.value
        self.onRemove = onRemove
        self.isRemoveHidden = isRemoveHidden
    }

    #if os(iOS)

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
                Button("Done") {
                    filter.value = textFieldValue
                    isTextFieldFocused = false
                }.foregroundColor(.blue)
            }
        }
        .padding(EdgeInsets(top: 2, leading: -6, bottom: 2, trailing: -8))
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
                Button(action: { onRemove(filter) }) {
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

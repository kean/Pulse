// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS) || os(macOS)

@available(iOS 15, *)
struct ConsoleCustomMessageFilterView: View {
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

    @FocusState private var isTextFieldFocused: Bool
    @State private var isEditing = false

    var body: some View {
        HStack(spacing: 8) {
            if !isEditing || !isHidingPickersDuring {
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
            #else
                .frame(minWidth: 200)
            #endif
                .onChange(of: isTextFieldFocused) { isTextFieldFocused in
                    withAnimation { isEditing = isTextFieldFocused }
                }
            if !isEditing || !isHidingPickersDuring {
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

    var isHidingPickersDuring: Bool {
#if os(macOS)
        return false
#else
        return true
#endif
    }

    // TODO: On iOS 16, inline picker looks OK
    private var fieldMenu: some View {
        FilterPickerMenu(title: filter.field.localizedTitle) {
            fieldPicker
        }
    }

    private var matchMenu: some View {
        FilterPickerMenu(title: filter.match.localizedTitle) {
            matchPicker
        }
    }

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

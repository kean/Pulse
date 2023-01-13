// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS) || os(macOS)

@available(iOS 15, *)
struct ConsoleCustomMessageFilterView: View {
    @Binding var filter: ConsoleCustomMessageFilter
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

    var isHidingPickersDuring: Bool {
#if os(macOS)
        return false
#else
        return true
#endif
    }

    // TODO: On iOS 16, inline picker looks OK
    private var fieldMenu: some View {
        ConsoleSearchInlinePickerMenu(title: filter.field.localizedTitle) {
            fieldPicker
        }
    }

    private var matchMenu: some View {
        ConsoleSearchInlinePickerMenu(title: filter.match.localizedTitle) {
            matchPicker
        }
    }

    private var fieldPicker: some View {
        Picker("Field", selection: $filter.field) {
            Text("Level").tag(ConsoleCustomMessageFilter.Field.level)
            Text("Label").tag(ConsoleCustomMessageFilter.Field.label)
            Text("Text").tag(ConsoleCustomMessageFilter.Field.message)
            Divider()
            Text("Metadata").tag(ConsoleCustomMessageFilter.Field.metadata)
            Divider()
            Text("File").tag(ConsoleCustomMessageFilter.Field.file)
        }
        .labelsHidden()
    }

    private var matchPicker: some View {
        Picker("Match", selection: $filter.match) {
            Text("Contains").tag(ConsoleCustomMessageFilter.Match.contains)
            Text("Not Contains").tag(ConsoleCustomMessageFilter.Match.notContains)
            Divider()
            Text("Equals").tag(ConsoleCustomMessageFilter.Match.equal)
            Text("Not Equals").tag(ConsoleCustomMessageFilter.Match.notEqual)
            Divider()
            Text("Begins With").tag(ConsoleCustomMessageFilter.Match.beginsWith)
            Divider()
            Text("Regex").tag(ConsoleCustomMessageFilter.Match.regex)
        }
        .labelsHidden()
    }
}

#endif

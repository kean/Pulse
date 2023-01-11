// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS) || os(macOS)

@available(iOS 15, *)
struct ConsoleCustomMessageFilterView: View {
    @ObservedObject var filter: ConsoleSearchFilter
    let onRemove: (() -> Void)?

    var body: some View {
        ConsoleCustomFilterView(text: $filter.value, onRemove: onRemove, pickers: {
            fieldMenu
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

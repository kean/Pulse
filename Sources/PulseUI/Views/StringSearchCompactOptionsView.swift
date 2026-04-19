// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI

/// A compact, single-row view for editing `StringSearchOptions`.
///
/// Layout: `[Text ▾] [Contains ▾]  ···  [Aa]`
///
/// The first picker selects kind (Text, Wildcard, Regex). The second picker
/// collapses kind + matching rule into a flat list of presets. The trailing
/// button toggles case sensitivity.
@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
package struct StringSearchCompactOptionsView: View {
    @Binding var options: StringSearchOptions

    package init(options: Binding<StringSearchOptions>) {
        self._options = options
    }

    package var body: some View {
        HStack {
            kindPicker
            matchPicker
            Spacer()
            caseSensitivityButton
        }
    }

    private var kindPicker: some View {
        Picker(selection: $options.kind) {
            ForEach(StringSearchOptions.Kind.allCases, id: \.self) {
                Text($0.rawValue).tag($0)
            }
        } label: {
            Image(systemName: "text.magnifyingglass")
        }
        .fixedSize()
    }

    @ViewBuilder
    private var matchPicker: some View {
        if let rules = options.allEligibleMatchingRules() {
            Picker("Match", selection: $options.rule) {
                ForEach(rules, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
    }

    private var caseSensitivityButton: some View {
        Button {
            options.caseSensitivity = options.caseSensitivity == .matchingCase ? .ignoringCase : .matchingCase
        } label: {
            Image(systemName: "textformat")
                .foregroundStyle(options.caseSensitivity == .matchingCase ? Color.accentColor : Color.secondary)
                .fontWeight(options.caseSensitivity == .matchingCase ? .medium : .regular)
        }
        .buttonStyle(.plain)
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
#Preview {
    @Previewable @State var options = StringSearchOptions()

    NavigationStack {
        Form {
            Section {
                StringSearchCompactOptionsView(options: $options)
            }
        }
    }
}

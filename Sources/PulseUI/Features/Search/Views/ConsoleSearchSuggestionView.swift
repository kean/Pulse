// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchSuggestionView: View {
    let suggestion: ConsoleSearchSuggestion
    @Binding var options: StringSearchOptions
    var isActionable = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if case .apply(let token) = suggestion.action, case .term = token {
                    Menu(content: { StringSearchOptionsMenu(options: $options) }) {
                        Image(systemName: "ellipsis.circle")
                    }
                } else {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                }
                Text(suggestion.text)
                    .lineLimit(1)
                Spacer()
                if isActionable {
                    Image(systemName: "return")
                }
            }
        }
    }
}

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchSuggestionView: View {
    @Binding var suggestion: ConsoleSearchSuggestion
    var isActionable = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if case .apply(let token) = suggestion.action, case .term(let term) = token {
                    Menu(content: {
                        StringSearchOptionsMenu(options: Binding(get: {
                            term.options
                        }, set: {
                            var term = term
                            term.options = $0
                            suggestion.action = .apply(.term(term))
                        }))
                    }, label: {
                        Image(systemName: "ellipsis.circle")
                    })
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

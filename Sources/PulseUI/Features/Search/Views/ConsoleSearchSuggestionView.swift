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
    var isActionable = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                Text(suggestion.text)
                    .lineLimit(1)
                Spacer()
                if isActionable {
                    Text("\\t")
                        .foregroundColor(.separator)
                }
            }
        }
    }
}

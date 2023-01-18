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

    var body: some View {
        Button(action: suggestion.onTap) {
            HStack {
                Image(systemName: "magnifyingglass")
                Text(suggestion.text)
                if isActionable {
                    Spacer()
                    Image(systemName: "return")
                }
            }
        }
    }
}

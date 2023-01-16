// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchSuggestedTokensView: View {
    @ObservedObject var viewModel: ConsoleSearchViewModel
    @Environment(\.isSearching) private var isSearching // important: scope

    // TODO: render values for suggestions using attributed strings
    var body: some View {
        if isSearching && !viewModel.suggestedTokens.isEmpty {
            Section(header: Text("Suggested Filters")) {
                ForEach(viewModel.suggestedTokens) { token in
                    Button(action: token.onTap) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text(token.text)
                        }
                    }
                }
            }
        }
    }
}

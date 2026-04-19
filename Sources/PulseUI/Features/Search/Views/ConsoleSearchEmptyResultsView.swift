// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS)

import SwiftUI
import Pulse
import CoreData

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct ConsoleSearchEmptyResultsView: View {
    @ObservedObject var viewModel: ConsoleSearchViewModel
    @EnvironmentObject private var searchBar: ConsoleSearchBarViewModel

    var body: some View {
        ContentUnavailableView.search(text: searchBar.text)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 24, leading: 16, bottom: 8, trailing: 16))
    }
}

#endif

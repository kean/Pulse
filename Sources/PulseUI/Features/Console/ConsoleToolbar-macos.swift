// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(macOS)

struct ConsoleToolbarToggleFiltersButton: View {
    @ObservedObject var viewModel: ConsoleToolbarViewModel

    var body: some View {
        Button(action: { viewModel.isFiltersPaneHidden.toggle() }, label: {
            Image(systemName: viewModel.isFiltersPaneHidden ? "line.horizontal.3.decrease.circle" : "line.horizontal.3.decrease.circle.fill")
                .foregroundColor(viewModel.isFiltersPaneHidden ? .secondary : .accentColor)
        }).help("Toggle Filters Panel (⌥⌘F)")
    }
}

struct ConsoleToolbarToggleOnlyErrorsButton: View {
    @ObservedObject var viewModel: ConsoleToolbarViewModel

    var body: some View {
        Button(action: { viewModel.isOnlyErrors.toggle() }) {
            Image(systemName: viewModel.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
                .foregroundColor(viewModel.isOnlyErrors ? .accentColor : .secondary)
        }.help("Toggle Show Only Errors (⇧⌘E)")
    }
}

final class ConsoleToolbarViewModel: ObservableObject {
    @Published var isFiltersPaneHidden = true
    @Published var isOnlyErrors = false
    @Published var isOnlyPins = false
    @Published var isSearchBarActive = false
}

#endif

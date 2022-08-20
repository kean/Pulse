// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(macOS)

struct ConsoleNowView: View {
    @ObservedObject var viewModel: ConsoleToolbarViewModel

    var body: some View {
        Button(action: { viewModel.isNowEnabled.toggle() }) {
            Image(systemName: viewModel.isNowEnabled ? "clock.fill" : "clock")
                .foregroundColor(viewModel.isNowEnabled ? Color.accentColor : Color.secondary)
        }.help("Automatically Scroll to Recent Messages (⇧⌘N)")
    }
}

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

struct ConsoleToolbarToggleVerticalView: View {
    @ObservedObject var viewModel: ConsoleToolbarViewModel

    var body: some View {
        Button(action: { viewModel.isVertical.toggle() }, label: {
            Image(systemName: viewModel.isVertical ? "square.split.2x1" : "square.split.1x2")
        }).help(viewModel.isVertical ? "Switch to Horizontal Layout" : "Switch to Vertical Layout")
    }
}

final class ConsoleToolbarViewModel: ObservableObject {
    @Published var isFiltersPaneHidden = true
    @AppStorage("console-view-is-vertical") var isVertical = true {
        didSet { objectWillChange.send() }
    }
    @Published var isOnlyErrors = false
    @Published var isOnlyPins = false
    @Published var isSearchBarActive = false
    @Published var isNowEnabled = true
}

#endif

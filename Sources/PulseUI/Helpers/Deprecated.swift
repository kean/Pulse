// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

@available(*, deprecated, message: "PinsView view is no longer available. Please use ConsoleView instead.")
public struct PinsView: View {
    public var body: some View {
        EmptyView()
    }
}

#if !os(macOS) && !os(watchOS)
@available(*, deprecated, message: "PPlease use ConsoleView pre-configured with .network mode")
public struct NetworkView: View {
    let viewModel: ConsoleViewModel

    public init(store: LoggerStore = .shared) {
        self.viewModel = ConsoleViewModel(store: store, mode: .network)
    }

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ConsoleView(viewModel: viewModel)
    }
}
#endif

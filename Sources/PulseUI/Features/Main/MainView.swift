// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS) || os(watchOS)

/// A MainView that contains the navigation view.
///
/// - note: To embed console into your own navigation, use ``ConsoleView`` directly.
public struct MainView: View {
    let viewModel: ConsoleViewModel

    public init(store: LoggerStore = .shared, onDismiss: (() -> Void)? = nil) {
        self.viewModel = ConsoleViewModel(store: store)
        self.viewModel.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationView {
            ConsoleView(viewModel: viewModel)
        }.navigationViewStyle(.stack)
    }
}

#if DEBUG
@available(*, deprecated, message: "Deprecated")
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(store: .mock)
    }
}

#endif

#endif

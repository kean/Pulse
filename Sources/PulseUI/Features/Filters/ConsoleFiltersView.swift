// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleFiltersView: View {
    let viewModel: ConsoleViewModel

    var body: some View {
        switch viewModel.mode {
        case .messages:
            ConsoleMessageFiltersView(viewModel: viewModel.searchViewModel)
        case .network:
            ConsoleNetworkFiltersView(viewModel: viewModel.searchViewModel)
        }
    }
}

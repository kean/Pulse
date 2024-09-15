// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS) || os(macOS)

import SwiftUI
import CoreData
import Pulse
import Combine

@available(iOS 16, visionOS 1, *)
struct ConsoleSearchContextMenu: View {
    @EnvironmentObject private var viewModel: ConsoleSearchViewModel

    var body: some View {
        Menu {
            StringSearchOptionsMenu(options: $viewModel.options)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
        }
    }
}
#endif

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

struct ConsoleListView: View {
    @ObservedObject var viewModel: ConsoleViewModel

    var body: some View {
#if os(iOS)
        List {
            Section(header: ConsoleToolbarView(viewModel: viewModel)) {
                cells
            }
        }
        .listStyle(.grouped)
#else
        List {
            cells
        }
#endif
    }

    private var cells: some View {
        ForEach(viewModel.visibleEntities, id: \.objectID) { entity in
            ConsoleEntityCell(entity: entity)
                .onAppear { viewModel.onAppearCell(with: entity.objectID) }
                .onDisappear { viewModel.onDisappearCell(with: entity.objectID) }
        }
    }
}

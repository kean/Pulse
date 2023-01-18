// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

func makeForEach(viewModel: ConsoleViewModel) -> some View {
    ForEach(viewModel.visibleEntities, id: \.objectID) { entity in
        ConsoleEntityCell(entity: entity)
            .onAppear { viewModel.onAppearCell(with: entity.objectID) }
            .onDisappear { viewModel.onDisappearCell(with: entity.objectID) }
    }
}

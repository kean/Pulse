// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

struct ConsoleListView: View {
    @ObservedObject var viewModel: ConsoleListViewModel

    var body: some View {
        ForEach(viewModel.visibleEntities, id: \.objectID) { entity in
            ConsoleEntityCell(entity: entity)
                .onAppear { viewModel.onAppearCell(with: entity.objectID) }
                .onDisappear { viewModel.onDisappearCell(with: entity.objectID) }
        }
    }
}

#warning("sort using currently selected sorting function")
//if #available(iOS 15, *) {
//    let groupByStatusCode = true
//    if groupByStatusCode && viewModel.mode == .network {
//        let groups = Dictionary(grouping: viewModel.entities as! [NetworkTaskEntity], by: { $0.statusCode })
//        ForEach(Array(groups.keys), id: \.self) {
//            let tasks = groups[$0]!.sorted(by: { $0.createdAt < $1.createdAt })
//            PlainListClearSectionHeader(title: "Status Code: \($0)")
//            ForEach(tasks, id: \.objectID) { entity in
//                ConsoleEntityCell(entity: entity)
//                    .onAppear { viewModel.onAppearCell(with: entity.objectID) }
//                    .onDisappear { viewModel.onDisappearCell(with: entity.objectID) }
//            }
//        }
//    }
//} else {
//    makeForEach(viewModel: viewModel)
//}

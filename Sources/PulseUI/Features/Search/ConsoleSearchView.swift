// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData

struct ConsoleSearchView: View {
    @ObservedObject var viewModel: ConsoleSearchViewModel

    var body: some View {
        List {
            ForEach(viewModel.results) { result in
                Section {
                    ConsoleEntityCell(entity: result.entity)
                }
            }
        }.listStyle(.insetGrouped)
    }
}

final class ConsoleSearchViewModel: ObservableObject {
    // TODO: add actual search
    let entities: [NSManagedObject]

    @Published private(set) var results: [ConsoleSearchResultViewModel] = []

    init(entities: [NSManagedObject]) {
        self.entities = entities

        self.results = entities.map {
            ConsoleSearchResultViewModel(entity: $0)
        }
    }
}

final class ConsoleSearchResultViewModel: Identifiable {
    var id: NSManagedObjectID { entity.objectID }
    let entity: NSManagedObject

    init(entity: NSManagedObject) {
        self.entity = entity
    }
}

#if DEBUG
struct ConsoleSearchView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConsoleSearchView(viewModel: .init(entities: try! LoggerStore.mock.allMessages()))
        }
    }
}
#endif

// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import CoreData
import Herald
import Combine

struct ConsoleMessagesRequestParameters {
    let searchText: String
}

final class ConsoleMessagesListViewModel: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
    private let controller: NSFetchedResultsController<MessageEntity>
    #warning("TODO: cleanup")
    private var bag: AnyCancellable?

    @Published var searchText: String = ""
    @Published private(set) var messages: ConsoleMessagesList

    init(context: NSManagedObjectContext, parameters: ConsoleMessagesRequestParameters = .init(searchText: "")) {
        let request = NSFetchRequest<MessageEntity>(entityName: "\(MessageEntity.self)")
        request.fetchBatchSize = 40
        parameters.apply(to: request)

        self.controller = NSFetchedResultsController<MessageEntity>(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        self.messages = ConsoleMessagesList(messages: self.controller.fetchedObjects ?? [])

        super.init()

        controller.delegate = self
        try? controller.performFetch()

        bag = $searchText.sink { [unowned self] in
            self.setParameters(.init(searchText: $0))
        }
    }

    private func setParameters(_ parameters: ConsoleMessagesRequestParameters) {
        parameters.apply(to: controller.fetchRequest)
        try? controller.performFetch()
        self.messages = ConsoleMessagesList(messages: self.controller.fetchedObjects ?? [])
    }

    // MARK: - NSFetchedResultsControllerDelegate

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.messages = ConsoleMessagesList(messages: self.controller.fetchedObjects ?? [])
    }
}

struct ConsoleMessagesList: RandomAccessCollection {
    private let messages: [MessageEntity]

    init(messages: [MessageEntity]) {
        self.messages = messages
    }

    typealias Index = Int

    var startIndex: Index { return messages.startIndex }
    var endIndex: Index { return messages.endIndex }
    func index(after i: Index) -> Index { i + 1 }

    subscript(index: Index) -> MessageEntity {
//        print("entity at \(index)")
        #warning("TODO: fix this")
        return messages[index]
    }
}

private extension ConsoleMessagesRequestParameters {
    func apply(to request: NSFetchRequest<MessageEntity>) {
        var predicates = [NSPredicate]()
        if searchText.count > 1 {
            predicates.append(NSPredicate(format: "text CONTAINS %@", searchText))
        }
        request.predicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        request.sortDescriptors = [NSSortDescriptor(keyPath: \MessageEntity.created, ascending: false)]
    }
}

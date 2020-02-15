// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import Herald
import CoreData

let mockMessagesStore: NSPersistentContainer = {
    let container = makeMockMessagesStore()
    populateStore(container)
    return container
}()

func makeMockMessagesStore() -> NSPersistentContainer {
    let container = NSPersistentContainer(name: "MockMessagesStore", managedObjectModel: coreDataModel)

    let store = NSPersistentStoreDescription()
    store.type = NSInMemoryStoreType
    container.persistentStoreDescriptions = [store]

    var isCompleted = false
    container.loadPersistentStores { _, error in
        assert(error == nil, "Failed to load persistent store: \(String(describing: error))")
        isCompleted = true
    }
    precondition(isCompleted)

    return container
}

private extension NSManagedObject {
    convenience init(using usedContext: NSManagedObjectContext) {
        let name = String(describing: type(of: self))
        let entity = NSEntityDescription.entity(forEntityName: name, in: usedContext)!
        self.init(entity: entity, insertInto: usedContext)
    }
}

private func populateStore(_ container: NSPersistentContainer) {
    precondition(Thread.isMainThread)

    let moc = container.viewContext

    func addMessage(_ closure: (MessageEntity) -> Void) {
        let message = MessageEntity(using: moc)
//        let message = MessageEntity(context: moc)
        closure(message)
        moc.insert(message)
    }

    addMessage {
        $0.created = Date() - 10.1
        $0.level = .info
        $0.system = "application"
        $0.category = "default"
        $0.session = "1"
        $0.text = "UIApplication.didFinishLaunching"
    }

    addMessage {
        $0.created = Date() - 10
        $0.level = .info
        $0.system = "application"
        $0.category = "default"
        $0.session = "1"
        $0.text = "UIApplication.willEnterForeground"
    }

    addMessage {
        $0.created = Date() - 8
        $0.level = .debug
        $0.system = "auth"
        $0.category = "default"
        $0.session = "1"
        $0.text = "🌐 Will authorize user with name \"kean@github.com\""
    }

    addMessage {
        $0.created = Date() - 6
        $0.level = .error
        $0.system = "auth"
        $0.category = "default"
        $0.session = "1"
        $0.text = "🌐 Authorization request failed with error 500"
    }

    addMessage {
        $0.created = Date() - 4
        $0.level = .debug
        $0.system = "auth"
        $0.category = "default"
        $0.session = "1"
        $0.text = "Replace this implementation with code to handle the error appropriately. fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development."
    }

    addMessage {
        $0.created = Date() - 3
        $0.level = .fatal
        $0.system = "default"
        $0.category = "default"
        $0.session = "1"
        $0.text = "💥 0xDEADBEAF"
    }

//    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
//        populateStore(container)
//    }

    try! moc.save()
}

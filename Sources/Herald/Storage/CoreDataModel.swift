// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).s

import CoreData

#warning("TODO: extract somewhere")
public let coreDataModel: NSManagedObjectModel = {
    let message = NSEntityDescription()
    message.name = "MessageEntity"
    message.managedObjectClassName = "MessageEntity"
    message.properties = [
        NSAttributeDescription(name: "created", type: .dateAttributeType),
        NSAttributeDescription(name: "level", type: .stringAttributeType),
        NSAttributeDescription(name: "system", type: .stringAttributeType),
        NSAttributeDescription(name: "category", type: .stringAttributeType),
        NSAttributeDescription(name: "session", type: .stringAttributeType),
        NSAttributeDescription(name: "message", type: .stringAttributeType)
    ]

    let model = NSManagedObjectModel()
    model.entities = [message]
    return model
}()

private extension NSAttributeDescription {
    convenience init(name: String, type: NSAttributeType) {
        self.init()
        self.name = name
        self.attributeType = type
    }

    convenience init(_ closure: (NSAttributeDescription) -> Void) {
        self.init()
        closure(self)
    }
}

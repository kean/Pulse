// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).s

import CoreData

public struct LoggerStorage {
    public static let coreDataModel: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        let message = NSEntityDescription()
        message.name = "MessageEntity"
        message.managedObjectClassName = MessageEntity.self.description()
        message.properties = [
            NSAttributeDescription(name: "created", type: .dateAttributeType),
            NSAttributeDescription(name: "level", type: .integer16AttributeType),
            NSAttributeDescription(name: "system", type: .stringAttributeType),
            NSAttributeDescription(name: "category", type: .stringAttributeType),
            NSAttributeDescription(name: "session", type: .stringAttributeType),
            NSAttributeDescription(name: "text", type: .stringAttributeType)
        ]

        model.entities = [message]
        return model
    }()
}

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

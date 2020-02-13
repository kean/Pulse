// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).s

import CoreData

final class MessageEntity: NSManagedObject {
    @NSManaged var created: Date
    @NSManaged var level: String
    @NSManaged var system: String
    @NSManaged var category: String
    @NSManaged var session: String
    @NSManaged var message: String
}

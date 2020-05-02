// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import CoreData

public final class MessageEntity: NSManagedObject {
    @NSManaged public var createdAt: Date
    @NSManaged public var level: String
    @NSManaged public var system: String
    @NSManaged public var category: String
    @NSManaged public var session: String
    @NSManaged public var text: String
}

// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import CoreData
import XCTest
import Logging
@testable import Pulse

/// - WARNING: These tests must be run in release node.
final class Performance2Tests: XCTestCase {
    var tempDir: TempDirectory!
    var storeURL: URL!

    var store: LoggerMessageStore2!

    override func setUp() {
        tempDir = try! TempDirectory()
        storeURL = tempDir.file(named: "test-store-perf")

        store = LoggerMessageStore2(storeURL: storeURL)
    }

    override func tearDown() {
        store = nil
        tempDir = nil
    }

    func testWriteMessages() {
        let handler = PersistentLogHandler2(label: "test-hanlder", store: store, makeCurrentDate: { Date() })

        measure {
            for _ in 0..<1_000 {
                handler.log(level: .debug, message: "message", metadata: nil, file: "a", function: "b", line: 10)
            }
            flush(store: store)
        }
    }

    func testReadAllMessages() throws {
        
    }

    #warning("TODO: reimplement")
//    func xtestQueryByLevel() {
//        let request = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
//        request.predicate = NSPredicate(format: "level == %@", Logger.Level.info.rawValue)
//
//        let moc = store.container.viewContext
//        populateStore()
//
//        measure {
//            let messages = (try? moc.fetch(request)) ?? []
//            XCTAssertEqual(messages.count, 20_000)
//        }
//    }
//
//    func xtestQueryByMetadata() {
//        let request = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
//        request.predicate = NSPredicate(format: "SUBQUERY(metadata, $entry, $entry.key == %@ AND $entry.value == %@).@count > 0", "system", "auth")
//
//        let moc = store.container.viewContext
//        populateStore()
//
//        measure {
//            let messages = (try? moc.fetch(request)) ?? []
//            XCTAssertEqual(messages.count, 10_000)
//        }
//    }
//
//    func populateStore() {
//        let moc = store.container.viewContext
//
//        func addMessage(_ closure: (MessageEntity) -> Void) {
//            let message = MessageEntity(context: moc)
//            closure(message)
//            moc.insert(message)
//        }
//
//        /// Create 60000 messages
//        for _ in 0..<10_000 {
//
//            addMessage {
//                $0.createdAt = Date() - 0.11
//                $0.level = Logger.Level.info.rawValue
//                $0.label = "application"
//                $0.session = PersistentLogHandler.logSessionId.uuidString
//                $0.text = "UIApplication.didFinishLaunching"
//                $0.metadata = [
//                    {
//                        let entity = MetadataEntity(context: moc)
//                        entity.key = "system"
//                        entity.value = "application"
//                        return entity
//                    }()
//                ]
//            }
//
//            addMessage {
//                $0.createdAt = Date() - 0.1
//                $0.level = Logger.Level.info.rawValue
//                $0.label = "application"
//                $0.session = PersistentLogHandler.logSessionId.uuidString
//                $0.text = "UIApplication.willEnterForeground"
//            }
//
//            addMessage {
//                $0.createdAt = Date() - 0.07
//                $0.level = Logger.Level.debug.rawValue
//                $0.label = "auth"
//                $0.session = PersistentLogHandler.logSessionId.uuidString
//                $0.text = "🌐 Will authorize user with name \"kean@github.com\""
//                $0.metadata = [
//                    {
//                        let entity = MetadataEntity(context: moc)
//                        entity.key = "system"
//                        entity.value = "auth"
//                        return entity
//                    }()
//                ]
//            }
//
//            addMessage {
//                $0.createdAt = Date() - 0.05
//                $0.level = Logger.Level.warning.rawValue
//                $0.label = "auth"
//                $0.session = PersistentLogHandler.logSessionId.uuidString
//                $0.text = "🌐 Authorization request failed with error 500"
//            }
//
//            addMessage {
//                $0.createdAt = Date() - 0.04
//                $0.level = Logger.Level.debug.rawValue
//                $0.label = "auth"
//                $0.session = PersistentLogHandler.logSessionId.uuidString
//                $0.text = """
//                Replace this implementation with code to handle the error appropriately. fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
//
//                2015-12-08 15:04:03.888 Conversion[76776:4410388] call stack:
//                (
//                0   Conversion                          0x000694b5 -[ViewController viewDidLoad] + 128
//                1   UIKit                               0x27259f55 <redacted> + 1028
//                ...
//                9   UIKit                               0x274f67a7 <redacted> + 134
//                10  FrontBoardServices                  0x2b358ca5 <redacted> + 232
//                11  FrontBoardServices                  0x2b358f91 <redacted> + 44
//                12  CoreFoundation                      0x230e87c7 <redacted> + 14
//                ...
//                16  CoreFoundation                      0x23038ecd CFRunLoopRunInMode + 108
//                17  UIKit                               0x272c7607 <redacted> + 526
//                18  UIKit                               0x272c22dd UIApplicationMain + 144
//                19  Conversion                          0x000767b5 main + 108
//                20  libdyld.dylib                       0x34f34873 <redacted> + 2
//                )
//                """
//            }
//
//            addMessage {
//                $0.createdAt = Date() - 0.03
//                $0.level = Logger.Level.critical.rawValue
//                $0.label = "default"
//                $0.session = PersistentLogHandler.logSessionId.uuidString
//                $0.text = "💥 0xDEADBEEF"
//            }
//        }
//
//        try! moc.save()
//        moc.reset()
//    }
}

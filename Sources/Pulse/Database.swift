// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import CoreData
import SQLite3

final class Database {
    fileprivate var ref: OpaquePointer

    init(url: URL) throws {
        var _ref: OpaquePointer!
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let status = sqlite3_open_v2(url.absoluteString, &_ref, flags, nil)
        guard status == SQLITE_OK else { throw Error(_ref, status) }
        self.ref = _ref
    }

    deinit {
        sqlite3_close(ref)
    }

    func create(_ string: String) throws {
        try Statement(self, string).execute()
    }
}

/// An SQL statement compiled into bytecode.
final class Statement {
    var db: Database
    var ref: OpaquePointer

    init(_ db: Database, _ string: String) throws {
        var ref: OpaquePointer!
        let status = sqlite3_prepare_v2(db.ref, string, -1, &ref, nil)
        guard status == SQLITE_OK else { throw Database.Error(db.ref, status) }
        self.ref = ref
        self.db = db
    }

    func execute() throws {
        let status = sqlite3_step(ref)
        guard status == SQLITE_DONE else { throw Database.Error(db.ref, status) }
    }

    deinit {
        sqlite3_finalize(ref)
    }
}

extension Database {
    struct Error: Swift.Error {
        let code: Int32
        let message: String

        var localizedDescription: String {
            return message
        }

        init(_ db: OpaquePointer?, _ code: Int32) {
            self.code = code
            self.message = String(cString: sqlite3_errmsg(db))
        }
    }
}

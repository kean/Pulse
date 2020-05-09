// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import CoreData
import SQLite3

final class Database {
    private var handle: OpaquePointer

    init(url: URL) throws {
        var _handle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let status = sqlite3_open_v2(url.absoluteString, &_handle, flags, nil)
        guard status == SQLITE_OK, let handle = _handle else {
            throw Error(code: status, handle: _handle)
        }
        self.handle = handle
    }

    deinit {
        sqlite3_close(handle)
    }
}

extension Database {
    struct Error: Swift.Error {
        let code: Int32
        let message: String

        var localizedDescription: String {
            return message
        }

        init(code: Int32, handle: OpaquePointer?) {
            self.code = code
            if let handle = handle {
                self.message = String(cString: sqlite3_errmsg(handle))
            } else {
                self.message = "Something went wrong"
            }
        }
    }
}

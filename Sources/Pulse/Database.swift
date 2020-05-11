// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import CoreData
import SQLite3

final class Database {
    fileprivate var ref: OpaquePointer!

    private var cache = [String: Statement]()

    init(url: URL, pragmas: [String: String] = [:]) throws {
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        try check(sqlite3_open_v2(url.absoluteString, &ref, flags, nil))

        for (option, value) in pragmas {
            try execute("PRAGMA \(option) = \(value)")
        }
    }

    deinit {
        sqlite3_close(ref)
    }

    // MARK: Select

    func select<T>(_ sql: String, _ map: (DataRow) -> T) throws -> [T] {
        let statement = try self.statement(sql)
        var items = [T]()
        while try check(sqlite3_step(statement.ref)) == SQLITE_ROW {
            let row = DataRow(ref: statement.ref)
            items.append(map(row))
        }
        return items
    }

    // MARK: Insert

    @discardableResult
    func insert(_ sql: String, _ parameters: [Statement.Parameter]) throws -> Int64 {
        return try insert(statement(sql), parameters)
    }

    @discardableResult
    func insert(_ statement: Statement, _ parameters: [Statement.Parameter]) throws -> Int64 {
        statement.bind(parameters)
        let status = sqlite3_step(statement.ref)
        sqlite3_clear_bindings(statement.ref)
        sqlite3_reset(statement.ref)
        try check(status)
        return Int64(sqlite3_last_insert_rowid(ref))
    }

    // MARK: Evaluate

    func evalute(_ sql: String) throws {
        try evalute(self.statement(sql))
    }

    private func evalute(_ statement: Statement) throws {
        try check(sqlite3_step(statement.ref))
    }

    func execute(_ sql: String) throws {
        try check(sqlite3_exec(ref, sql, nil, nil, nil))
    }

    // MARK: Private (Compiling Statements)

    private func statement(_ sql: String) throws -> Statement {
        if let statement = cache[sql] {
            return statement
        }
        let statement = try compile(sql)
        cache[sql] = statement
        return statement
    }

    private func compile(_ sql: String) throws -> Statement {
        var ref: OpaquePointer!
        try check(sqlite3_prepare_v2(self.ref, sql, -1, &ref, nil))
        return Statement(ref: ref)
    }

    // MARK: Private (Check)

    @discardableResult
    private func check(_ code: Int32) throws -> Int32 {
        guard let error = Database.Error(code: code, db: ref) else { return code }
        throw error
    }
}

/// An SQL statement compiled into bytecode.
final class Statement {
    var ref: OpaquePointer

    init(ref: OpaquePointer) {
        self.ref = ref
    }

    deinit {
        sqlite3_finalize(ref)
    }

    // MARK: Bind

    func bind(_ parameters: [Parameter]) {
        for (parameter, index) in zip(parameters, parameters.indices) {
            bind(parameter, at: Int32(index+1))
        }
    }

    func bind(_ parameter: Parameter, at index: Int32) {
        switch parameter {
        case let .int(value):
            sqlite3_bind_int(ref, index, value)
        case let .string(value):
            sqlite3_bind_text(ref, index, value, -1, SQLITE_TRANSIENT)
        case let .timestamp(value):
            sqlite3_bind_double(ref, index, value.timeIntervalSince1970)
        }
    }

    enum Parameter {
        case int(Int32)
        case string(String)
        case timestamp(Date)
    }
}

struct DataRow {
    let ref: OpaquePointer

    subscript(index: Int32) -> Int {
        Int(sqlite3_column_int(ref, index))
    }

    subscript(index: Int32) -> String {
        guard let pointer = sqlite3_column_text(ref, index) else { return "" }
        return String(cString: pointer)
    }

    subscript(index: Int32) -> Date {
        Date(timeIntervalSince1970: sqlite3_column_double(ref, index))
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

extension Database {
    struct Error: Swift.Error, CustomStringConvertible {
        // MARK: Properties

        /// The [code](https://www.sqlite.org/c3ref/c_abort.html) of the specific error encountered by SQLite.
        public let code: Int32

        /// The [message](https://www.sqlite.org/c3ref/errcode.html) of the specific error encountered by SQLite.
        public var message: String

        /// A textual description of the [error code](https://www.sqlite.org/c3ref/errcode.html).
        public var codeDescription: String { return String(cString: sqlite3_errstr(code)) }

        private static let successCodes: Set = [SQLITE_OK, SQLITE_ROW, SQLITE_DONE]

        // MARK: Initialization

        init?(code: Int32, db: OpaquePointer) {
            guard !Self.successCodes.contains(code) else { return nil }

            self.code = code
            self.message = String(cString: sqlite3_errmsg(db))
        }

        init(db: OpaquePointer) {
            self.code = sqlite3_errcode(db)
            self.message = String(cString: sqlite3_errmsg(db))
        }

        init(code: Int32, message: String) {
            self.code = code
            self.message = message
        }

        public var description: String {
            let messageArray = [
                "message=\"\(message)\"",
                "code=\(code)",
                "codeDescription=\"\(codeDescription)\""
            ]

            return "{ " + messageArray.joined(separator: ", ") + " }"
        }
    }
}

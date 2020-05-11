// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import CoreData
import SQLite3

/// A database connection.
///
/// For more details about using multiple database connections to improve concurrency, please refer to the
/// [documentation](https://www.sqlite.org/isolation.html).
final class SQLConnection {
    fileprivate var ref: OpaquePointer!

    enum Location {
        /// Database stored on disk.
        case disk(url: URL)
        /// The database will be opened as an in-memory database. The database
        /// is named by the "filename" argument for the purposes of cache-sharing,
        /// if shared cache mode is enabled, but the "filename" is otherwise ignored.
        ///
        /// The default name is `:memory:` which creates a private, temporary
        /// in-memory database for the connection. This in-memory database will
        /// vanish when the database connection is closed.
        case memory(name: String = ":memory:")

        /// A private, temporary on-disk database will be created. This private
        /// database will be automatically deleted as soon as the database
        /// connection is closed.
        case temporary
    }

    enum Mode {
        /// The database is opened in read-only mode. If the database does not
        /// already exist, an error is returned.
        case readonly
        /// The database is opened for reading and writing if possible, or reading only
        /// if the file is write protected by the operating system. In either case the
        /// database must already exist, otherwise an error is returned.
        ///
        /// - parameter create: The database is created if it does not already exist.
        /// `true` by default.
        case readwrite(create: Bool = true)
    }

    struct Options {
        /// SQLite includes a special "shared-cache" mode (disabled by default)
        /// intended for use in embedded servers. If shared-cache mode is enabled
        /// and a process establishes multiple connections to the same database,
        /// the connections share a single data and schema cache. This can
        /// significantly reduce the quantity of memory and IO required by the system.
        ///
        /// [sharedcache.html](https://www.sqlite.org/sharedcache.html)
        var isSharedCacheEnabled = false

        /// By default, uses `serialized` threading mode.
        var threadingMode: ThreadingMode = .default
    }

    /// A threading mode.
    ///
    /// - note: A single-threaded mode can only be selected at (SQL) compile time.
    ///
    /// - note: [threadsafe.html](https://www.sqlite.org/threadsafe.html)
    enum ThreadingMode {
        /// Use the default theading mode configured when SQL was started.
        case `default`
        /// In this mode, SQLite can be safely used by multiple threads provided
        /// that no single database connection is used simultaneously in two or
        /// more threads.
        case multiThreaded
        /// In serialized mode, SQLite can be safely used by multiple threads
        /// with no restriction.
        case serialized
    }

    #warning("TODO: do we need to cache statements?")
    private var cache = [String: Statement]()

    /// Opens a new database read-write connection with the given url. If the
    /// database doesn't exist, creats it. When deallocated, the connection gets
    /// closed automatically. Throws an `SQLError` if it fails open a connection.
    ///
    /// - parameter url: Database URL.
    convenience init(url: URL) throws {
        try self.init(location: .disk(url: url))
    }

    /// Opens a new database connection with the given parameters. When deallocated,
    /// the connection gets closed automatically. Throws an `SQLError` if it fails
    /// open a connection.
    ///
    /// - parameter mode: Specifies whether open the database for reading, writing
    /// or both, and whether to create it on write. `.readwrite(create: true)` by default.
    /// - parameter options: See `SQLConnectionOptions` for more information.
    init(location: Location, mode: Mode = .readwrite(create: true), options: Options = Options()) throws {
        let path: String
        var flags: Int32 = 0

        switch mode {
        case .readonly:
            flags |= SQLITE_OPEN_READONLY
        case let .readwrite(create):
            flags |= SQLITE_OPEN_READWRITE
            if create {
                 flags |= SQLITE_OPEN_CREATE
            }
        }
        switch location {
        case let .disk(url):
            path = url.absoluteString
        case let .memory(name):
            path = name
            if name != ":memory:" {
                flags |= SQLITE_OPEN_MEMORY
            }
        case .temporary:
            path = ""
        }

        flags |= options.isSharedCacheEnabled ?
            SQLITE_OPEN_SHAREDCACHE :
            SQLITE_OPEN_PRIVATECACHE

        switch options.threadingMode {
        case .default:
            break // Do nothing
        case .multiThreaded:
            flags |= SQLITE_OPEN_NOMUTEX
        case .serialized:
            flags |= SQLITE_OPEN_FULLMUTEX
        }

        try isOK(sqlite3_open_v2(path, &ref, flags, nil))
    }

    deinit {
        sqlite3_close(ref)
    }

    // MARK: Select

    #warning("TODO: add select with parameters")
    #warning("TODO: add an option to cache compiled queries")
    func select<T>(_ sql: String, _ map: (DataRow) -> T) throws -> [T] {
        let statement = try self.statement(sql)
        var items = [T]()
        while try isOK(sqlite3_step(statement.ref)) == SQLITE_ROW {
            let row = DataRow(ref: statement.ref)
            items.append(map(row))
        }
        return items
    }

    // MARK: Insert

    @discardableResult
    func insert(_ sql: String, _ parameters: [Statement.Parameter]) throws -> Int64 {
        let statement = try self.statement(sql)
        statement.bind(parameters)
        let status = sqlite3_step(statement.ref)
        sqlite3_clear_bindings(statement.ref)
        sqlite3_reset(statement.ref)
        try isOK(status)
        return Int64(sqlite3_last_insert_rowid(ref))
    }

    // MARK: Execute

    /// Runs the given one-shot SQL statement.
    ///
    /// - note: Use it instead of `evaluate` when you don't want the connection
    /// to cache the compiled statement.
    ///
    /// - note: Uses [sqlite3_exec](https://www.sqlite.org/c3ref/exec.html).
    func execute(_ sql: String) throws {
        try isOK(sqlite3_exec(ref, sql, nil, nil, nil))
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
        try isOK(sqlite3_prepare_v2(self.ref, sql, -1, &ref, nil))
        return Statement(ref: ref)
    }

    // MARK: Private (Check)

    @discardableResult
    private func isOK(_ code: Int32) throws -> Int32 {
        guard let error = SQLError(code: code, db: ref) else { return code }
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

struct SQLError: Swift.Error, CustomStringConvertible {
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

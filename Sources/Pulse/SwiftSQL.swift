// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import CoreData
import SQLite3

// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import SQLite3

/// A database connection.
///
/// When deallocated, the connection gets closed automatically.
///
/// # Concurrency
///
/// For more details about using multiple database connections to improve concurrency, please refer to the
/// [documentation](https://www.sqlite.org/isolation.html).
final class SQLConnection {
    private(set) var ref: OpaquePointer!

    /// Returns the last [INSERT row id](https://www.sqlite.org/c3ref/last_insert_rowid.html)
    /// of the database connection. Returns `0` if no successfull INSERT into rowid
    /// tables have ever occured on the connection.
    ///
    /// # Threading
    ///
    /// If a separate thread performs a new INSERT on the same database connection
    /// while the `lastInsertRowID` property is running and thus changes the last
    /// insert rowid, then the value returned by `lastInsertRowID` is unpredictable
    /// and might not equal either the old or the new last insert rowid.
    ///
    /// - note: As well as being set automatically as rows are inserted into database tables,
    /// the value returned by this function may be set explicitly.
    var lastInsertRowID: Int64 {
        get { sqlite3_last_insert_rowid(ref) }
        set { sqlite3_set_last_insert_rowid(ref, newValue) }
    }

    /// [Opens](https://www.sqlite.org/c3ref/open.html) a new database connection
    /// with the given parameters. Throws an `SQLError` if it fails open a connection.
    ///
    /// - parameter url: Database URL.
    convenience init(url: URL) throws {
        try self.init(location: .disk(url: url))
    }

    /// [Opens](https://www.sqlite.org/c3ref/open.html) a new database connection
    /// with the given parameters. Throws an `SQLError` if it fails open a connection.
    ///
    /// - parameter mode: Specifies whether open the database for reading, writing
    /// or both, and whether to create it on write. `.writable(create: true)` by default.
    /// - parameter options: See `SQLConnectionOptions` for more information.
    ///
    /// - note: See [SQLite: Result and Error Codes](https://www.sqlite.org/rescode.html)
    /// for more information.
    init(location: Location, mode: Mode = .writable(create: true), options: Options = Options()) throws {
        let path: String
        var flags: Int32 = 0

        switch mode {
        case .readonly:
            flags |= SQLITE_OPEN_READONLY
        case let .writable(create):
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
        case .multithreaded:
            flags |= SQLITE_OPEN_NOMUTEX
        case .serialized:
            flags |= SQLITE_OPEN_FULLMUTEX
        }

        try isOK(sqlite3_open_v2(path, &ref, flags, nil))
    }

    deinit {
         try? close()
     }

    // MARK: Execute

    /// [Executes](https://www.sqlite.org/c3ref/exec.html) the given one-shot SQL statement.
    func execute(_ sql: String) throws {
        try isOK(sqlite3_exec(ref, sql, nil, nil, nil))
    }

    // MARK: Prepare (Compile) Statements

    /// To execute an SQL statement, it must first be [compiled](https://www.sqlite.org/c3ref/prepare.html)
    /// into a byte-code program using one of these routines.
    ///
    /// If the database schema changes, instead of returning do, `step()` will
    /// automatically recompile the SQL statement and try to run it again.
    /// The nubmer of reties is limited.
    ///
    func prepare(_ sql: String) throws -> SQLStatement {
        var ref: OpaquePointer!
        try isOK(sqlite3_prepare_v2(self.ref, sql, -1, &ref, nil))
        return SQLStatement(db: self, ref: ref)
    }

    // MARK: Closing

    /// [Closes](https://www.sqlite.org/c3ref/close.html) the connection.
    ///
    /// If `close()` is called with unfinalized prepared statements and/or
    /// unfinished backups, then the database connection becomes an unusable
    /// "zombie" which will automatically be destroyed when the last prepared
    /// statement is finalized or the last backup is finished.
    ///
    /// Applications should finalize all prepared statements, close all BLOB handles,
    /// and finish all backup objects associated with the connection object prior
    /// to attempting to close it. If close() is called on a database connection
    /// that still has outstanding prepared statements, BLOB handles, backup objects
    /// then it completes successfully and the deallocation of resources is deferred
    /// until all prepared statements, BLOB handles, and backup objects are also destroyed.
    ///
    /// If a connection is destroyed while a transaction is open, the transaction is
    /// automatically rolled back.
    func close() throws {
        try isOK(sqlite3_close_v2(ref))
    }

    /// This function causes any pending database operation to [abort](https://www.sqlite.org/c3ref/interrupt.html)
    /// and return at its earliest opportunity.
    ///
    /// This routine is typically called in response to a user cancelling an
    /// operation where the user wants a long query operation to halt immediately.
    ///
    /// It is safe to call this routine from a thread different from the thread
    /// that is currently running the database operation. But it is not safe to
    /// call this routine with a database connection that is closed or might
    /// close before `interrupt()` returns.
    ///
    /// If an SQL operation is very nearly finished at the time when `interrupt()`
    /// is called, then it might not have an opportunity to be interrupted and
    /// might continue to completion.
    ///
    /// An SQL operation that is interrupted will fail with `.interrupted` error.
    /// If the interrupted SQL operation is an INSERT, UPDATE, or DELETE that is
    /// inside an explicit transaction, then the entire transaction will be rolled
    /// back automatically.
    func interrupt() {
        sqlite3_interrupt(ref)
    }

    // MARK: Private

    @discardableResult
    func isOK(_ code: Int32) throws -> Int32 {
        guard let error = SQLError(code: code, db: ref) else { return code }
        throw error
    }
}

// MARK: - SQLConnection (Options)

extension SQLConnection {
    /// Specifies the [location](https://www.sqlite.org/c3ref/open.html) where
    /// the database is stored.
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

    /// The [mode](https://www.sqlite.org/c3ref/open.html) with which to open
    /// the database connection.
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
        case writable(create: Bool = true)
    }

    /// The [options](https://www.sqlite.org/c3ref/open.html) with which to open
    /// the connection.
    struct Options {
        /// SQLite includes a special "shared-cache" mode (disabled by default)
        /// intended for use in embedded servers. If shared-cache mode is enabled
        /// and a process establishes multiple connections to the same database,
        /// the connections share a single data and schema cache. This can
        /// significantly reduce the quantity of memory and IO required by the system.
        ///
        /// [sharedcache.html](https://www.sqlite.org/sharedcache.html)
        var isSharedCacheEnabled: Bool

        /// By default, uses `serialized` threading mode.
        var threadingMode: ThreadingMode

        init(isSharedCacheEnabled: Bool = false, threadingMode: ThreadingMode = .default) {
            self.isSharedCacheEnabled = isSharedCacheEnabled
            self.threadingMode = threadingMode
        }
    }

    /// Specifies a [threading mode](https://www.sqlite.org/threadsafe.html) for the connection
    enum ThreadingMode {
        /// Use the default theading mode configured when SQL was started.
        case `default`
        /// In this mode, SQLite can be safely used by multiple threads provided
        /// that no single database connection is used simultaneously in two or
        /// more threads.
        case multithreaded
        /// In serialized mode, SQLite can be safely used by multiple threads
        /// with no restriction.
        case serialized
    }
}

/// Represents a data type supported by SQLite.
///
/// - note: To add support for custom data types, like `Bool` or `Date`, see
/// [Advanced Usage Guide](https://github.com/kean/SwiftSQL/blob/0.1.0/Docs/advanced-usage-guide.md)
protocol SQLDataType {
    func sqlBind(statement: OpaquePointer, index: Int32)
    static func sqlColumn(statement: OpaquePointer, index: Int32) -> Self
}

extension Int: SQLDataType {
    func sqlBind(statement: OpaquePointer, index: Int32) {
        sqlite3_bind_int64(statement, index, Int64(self))
    }

    static func sqlColumn(statement: OpaquePointer, index: Int32) -> Int {
        Int(sqlite3_column_int64(statement, index))
    }
}

extension Int32: SQLDataType {
    func sqlBind(statement: OpaquePointer, index: Int32) {
        sqlite3_bind_int(statement, index, self)
    }

    static func sqlColumn(statement: OpaquePointer, index: Int32) -> Int32 {
        sqlite3_column_int(statement, index)
    }
}

extension Int64: SQLDataType {
    func sqlBind(statement: OpaquePointer, index: Int32) {
        sqlite3_bind_int64(statement, index, self)
    }

    static func sqlColumn(statement: OpaquePointer, index: Int32) -> Int64 {
        sqlite3_column_int64(statement, index)
    }
}

extension Double: SQLDataType {
    func sqlBind(statement: OpaquePointer, index: Int32) {
        sqlite3_bind_double(statement, index, self)
    }

    static func sqlColumn(statement: OpaquePointer, index: Int32) -> Double {
        sqlite3_column_double(statement, index)
    }
}

extension String: SQLDataType {
    func sqlBind(statement: OpaquePointer, index: Int32) {
        sqlite3_bind_text(statement, index, self, -1, SQLITE_TRANSIENT)
    }

    static func sqlColumn(statement: OpaquePointer, index: Int32) -> String {
        guard let pointer = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: pointer)
    }
}

extension Data: SQLDataType {
    func sqlBind(statement: OpaquePointer, index: Int32) {
        sqlite3_bind_blob(statement, Int32(index), Array(self), Int32(count), SQLITE_TRANSIENT)
    }

    static func sqlColumn(statement: OpaquePointer, index: Int32) -> Data {
        guard let pointer = sqlite3_column_blob(statement, Int32(index)) else {
            return Data()
        }
        let count = Int(sqlite3_column_bytes(statement, Int32(index)))
        return Data(bytes: pointer, count: count)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Represents an SQLite error.
struct SQLError: Swift.Error {
    /// The [error code](https://www.sqlite.org/c3ref/c_abort.html).
    let code: Int32

    /// The [error message](https://www.sqlite.org/c3ref/errcode.html).
    var message: String

    init?(code: Int32, db: OpaquePointer) {
        guard !(code == SQLITE_ROW || code == SQLITE_OK || code == SQLITE_DONE) else { return nil }

        self.code = code
        self.message = String(cString: sqlite3_errmsg(db))
    }

    init(code: Int32, message: String) {
        self.code = code
        self.message = message
    }
}

/// An SQL statement compiled into bytecode.
///
/// An instance of this object represents a single SQL statement that has been
/// compiled into binary form and is ready to be evaluated.
///
/// Think of each SQL statement as a separate computer program. The original SQL
/// text is source code. A prepared statement object is the compiled object code.
/// All SQL must be converted into a prepared statement before it can be run.
///
/// The life-cycle of a prepared statement object usually goes like this:
///
/// 1. Create the prepared statement object using a connection:
///
///     let db = try SQLConnection(url: <#store_url#>)
///     let statement = try db.prepare("""
///     INSERT INTO Users (Name, Surname) VALUES (?, ?)
///     """)
///
/// 2. Bind values to parameters using one of the `bind()` methods. The provided
/// values must be one of the data types supported by SQLite (see `SQLDataType` for
/// more info)
///
///     try statement.bind("Alexander", "Grebenyuk")
///
/// 3. Execute the statement (you can chain it after `bind()`)
///
///     // Using `step()` to execute a statement.
///     try statement.step()
///
///     // If it's a `SELECT` query
///     while try statement.step() {
///         let name: String = statement.column(at: 0)
///     }
///
/// 4. (Optional) To reuse the compiled statementt, reset it and go back to step 2,
/// do this zero or more times.
///
///     try statement.reset()
///
/// The compiled statement is going to be automatically destroyed when the
/// `SQLStatement` object gets deallocated.
final class SQLStatement {
    let db: SQLConnection
    let ref: OpaquePointer

    init(db: SQLConnection, ref: OpaquePointer) {
        self.db = db
        self.ref = ref
    }

    deinit {
        sqlite3_finalize(ref)
    }

    // MARK: Execute

    /// Executes the statement and returns true of the row is available.
    /// Returns nil if the statement is finished executing and no more data
    /// is available. Throws an error if an error is encountered.
    ///
    ///
    ///     let statement = try db.prepare("SELECT Name, Level FROM Users ORDER BY Level ASC")
    ///
    ///     var objects = [User]()
    ///     while let row = try statement.next() {
    ///         let user = User(name: row[0], level: row[1])
    ///         objects.append(user)
    ///     }
    ///
    /// - note: See [SQLite: Result and Error Codes](https://www.sqlite.org/rescode.html)
    /// for more information.
    func step() throws -> Bool {
        try isOK(sqlite3_step(ref)) == SQLITE_ROW
    }

    /// Executes the statement. Throws an error if an error is occured.
    ///
    /// - note: See [SQLite: Result and Error Codes](https://www.sqlite.org/rescode.html)
    /// for more information.
    func execute() throws {
        try isOK(sqlite3_step(ref))
    }

    // MARK: Binding Parameters

    /// Binds values to the statement parameters.
    ///
    ///     try db.prepare("INSERT INTO Users (Level, Name) VALUES (?, ?)")
    ///        .bind(80, "John")
    ///        .execute()
    ///
    @discardableResult
    func bind(_ parameters: SQLDataType?...) throws -> Self {
        try bind(parameters)
        return self
    }

    /// Binds values to the statement parameters.
    ///
    ///     try db.prepare("INSERT INTO Users (Level, Name) VALUES (?, ?)")
    ///        .bind([80, "John"])
    ///        .execute()
    ///
    @discardableResult
    func bind(_ parameters: [SQLDataType?]) throws -> Self {
        for (index, value) in zip(parameters.indices, parameters) {
            try _bind(value, at: Int32(index + 1))
        }
        return self
    }

    /// Binds values to the named statement parameters.
    ///
    ///     let row = try db.prepare("SELECT Level, Name FROM Users WHERE Name = :param LIMIT 1")
    ///         .bind([":param": "John""])
    ///         .next()
    ///
    /// - parameter name: The name of the parameter. If the name is missing, throws
    /// an error.
    @discardableResult
    func bind(_ parameters: [String: SQLDataType?]) throws -> Self {
        for (key, value) in parameters {
            try _bind(value, for: key)
        }
        return self
    }

    /// Binds values to the parameter with the given name.
    ///
    ///     let row = try db.prepare("SELECT Level, Name FROM Users WHERE Name = :param LIMIT 1")
    ///         .bind("John", for: ":param")
    ///         .next()
    ///
    /// - parameter name: The name of the parameter. If the name is missing, throws
    /// an error.
    @discardableResult
    func bind(_ value: SQLDataType?, for name: String) throws -> Self {
        try _bind(value, for: name)
        return self
    }

    /// Binds value to the given index.
    ///
    /// - parameter index: The index starts at 0.
    @discardableResult
    func bind(_ value: SQLDataType?, at index: Int) throws -> Self {
        try _bind(value, at: Int32(index + 1))
        return self
    }

    private func _bind(_ value: SQLDataType?, for name: String) throws {
        let index = sqlite3_bind_parameter_index(ref, name)
        guard index > 0 else {
            throw SQLError(code: SQLITE_MISUSE, message: "Failed to find parameter named \(name)")
        }
        try _bind(value, at: index)
    }

    private func _bind(_ value: SQLDataType?, at index: Int32) throws {
        if let value = value {
            value.sqlBind(statement: ref, index: index)
        } else {
            sqlite3_bind_null(ref, index)
        }
    }

    /// Clears bindings.
    ///
    /// It is not commonly useful to evaluate the exact same SQL statement more
    /// than once. More often, one wants to evaluate similar statements. For example,
    /// you might want to evaluate an INSERT statement multiple times with different
    /// values. Or you might want to evaluate the same query multiple times using
    /// a different key in the WHERE clause. To accommodate this, SQLite allows SQL
    /// statements to contain parameters which are "bound" to values prior to being
    /// evaluated. These values can later be changed and the same prepared statement
    /// can be evaluated a second time using the new values.
    ///
    /// `clearBindings()` allows you to clear those bound values. It is not required
    /// to call `clearBindings()` every time. Simplify overwriting the existing values
    /// does the trick.
    @discardableResult
    func clearBindings() throws -> SQLStatement {
        try isOK(sqlite3_clear_bindings(ref))
        return self
    }

    /// Returns the [number of the SQL parameters](https://www.sqlite.org/c3ref/bind_parameter_count.html).
    var bindParameterCount: Int {
        Int(sqlite3_bind_parameter_count(ref))
    }

    // MARK: Accessing Columns

    /// Returns a single column of the current result row of a query.
    ///
    /// If the SQL statement does not currently point to a valid row, or if the
    /// column index is out of range, the result is undefined.
    ///
    /// - parameter index: The leftmost column of the result set has the index 0.
    func column<T: SQLDataType>(at index: Int) -> T {
        T.sqlColumn(statement: ref, index: Int32(index))
    }

    /// Returns a single column of the current result row of a query. If the
    /// value is `Null`, returns `nil.`
    ///
    /// If the SQL statement does not currently point to a valid row, or if the
    /// column index is out of range, the result is undefined.
    ///
    /// - parameter index: The leftmost column of the result set has the index 0.
    func column<T: SQLDataType>(at index: Int) -> T? {
        if sqlite3_column_type(ref, Int32(index)) == SQLITE_NULL {
            return nil
        } else {
            return T.sqlColumn(statement: ref, index: Int32(index))
        }
    }

    /// Return the number of columns in the result set returned by the statement.
    ///
    /// If this routine returns 0, that means the prepared statement returns no data
    /// (for example an UPDATE). However, just because this routine returns a positive
    /// number does not mean that one or more rows of data will be returned.
    var columnCount: Int {
        Int(sqlite3_column_count(ref))
    }

    /// These routines return the name assigned to a particular column in the result
    /// set of a SELECT statement.
    ///
    /// The name of a result column is the value of the "AS" clause for that column,
    /// if there is an AS clause. If there is no AS clause then the name of the
    /// column is unspecified and may change from one release of SQLite to the next.
    func columnName(at index: Int) -> String {
        String(cString: sqlite3_column_name(ref, Int32(index)))
    }

    // MARK: Reset

    /// Resets the expression and prepares it for the new execution.
    ///
    /// SQLite allows the same prepared statement to be evaluated multiple times.
    /// After a prepared statement has been evaluated it can be reset in order to
    /// be evaluated again by a call to `reset()`. Reusing compiled statements
    /// can give a significant performance improvement.
    @discardableResult
    func reset() throws -> SQLStatement {
        try isOK(sqlite3_reset(ref))
        return self
    }

    // MARK: Private

    @discardableResult
    private func isOK(_ code: Int32) throws -> Int32 {
        try db.isOK(code)
    }
}

extension Date: SQLDataType {
    func sqlBind(statement: OpaquePointer, index: Int32) {
        sqlite3_bind_double(statement, index, timeIntervalSince1970)
    }

    static func sqlColumn(statement: OpaquePointer, index: Int32) -> Date {
        Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
    }
}

extension SQLStatement {
    /// Fetches the next row.
    func row<T: SQLRowDecodable>(_ type: T.Type) throws -> T? {
        guard try step() else {
            return nil
        }
        return try T(row: SQLRow(statement: self))
    }

    /// Fetches the first `count` rows returned by the statement. By default,
    /// fetches all rows.
    func rows<T: SQLRowDecodable>(_ type: T.Type, count: Int? = nil) throws -> [T] {
        var objects = [T]()
        let limit = count ?? Int.max
        while let object = try row(T.self), objects.count < limit {
            objects.append(object)
        }
        return objects
    }
}

/// Represents a single row returned by the SQL statement.
///
/// - warning: This is a leaky abstraction. This is not a real value type, it
/// just wraps the underlying statement. If the statement moves to the next
/// row by calling `step()`, the row is also going to point to the new row.
struct SQLRow {
    /// The underlying statement.
    let statement: SQLStatement // Storing as strong reference doesn't seem to affect performance

    init(statement: SQLStatement) {
        self.statement = statement
    }

    /// Returns a single column of the current result row of a query.
    ///
    /// If the SQL statement does not currently point to a valid row, or if the
    /// column index is out of range, the result is undefined.
    ///
    /// - parameter index: The leftmost column of the result set has the index 0.
    subscript<T: SQLDataType>(index: Int) -> T {
        statement.column(at: index)
    }

    /// Returns a single column of the current result row of a query. If the
    /// value is `Null`, returns `nil.`
    ///
    /// If the SQL statement does not currently point to a valid row, or if the
    /// column index is out of range, the result is undefined.
    ///
    /// - parameter index: The leftmost column of the result set has the index 0.
    subscript<T: SQLDataType>(index: Int) -> T? {
        statement.column(at: index)
    }
}

protocol SQLRowDecodable {
    init(row: SQLRow) throws
}

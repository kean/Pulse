// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Security

struct Keychain {
    let service: String
    let accessGroup: String?

    init(service: String = Bundle.main.bundleIdentifier!, accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }
}

extension Keychain {
    func string(forKey key: String) -> String? {
        data(forKey: key).flatMap { String(data: $0, encoding: .utf8) }
    }

    func data(forKey key: String) -> Data? {
        let query = self.getOneQuery(byKey: key)
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    func set(_ string: String, forKey key: String) throws {
        try set(Data(string.utf8), forKey: key)
    }

    func set(_ data: Data, forKey key: String) throws {
        let addItemQuery = setQuery(forKey: key, data: data)
        var status = SecItemAdd(addItemQuery as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateQuery = baseQuery(withKey: key)
            let updateAttributes: [String: Any] = [kSecValueData as String: data]
            status = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
        }
        try check(status)
    }

    func deleteItem(forKey key: String) throws {
        let query = self.baseQuery(withKey: key)
        try check(SecItemDelete(query as CFDictionary))
    }

    func deleteAll() throws {
        var query = self.baseQuery()
#if os(macOS)
        query[kSecMatchLimit as String] = kSecMatchLimitAll
#endif
        let status = SecItemDelete(query as CFDictionary)
        guard status != errSecItemNotFound else { return }
        try check(status)
    }
}

private func check(_ status: OSStatus) throws {
    if status == errSecSuccess { return }
    throw KeychainError(status: status)
}

struct KeychainError: Error {
    let status: OSStatus
}

private extension Keychain {
    func baseQuery(withKey key: String? = nil, data: Data? = nil) -> [String: Any] {
        var query: [String: Any] = [:]
        query[kSecClass as String] = kSecClassGenericPassword
        query[kSecAttrService as String] = self.service
        if let key = key {
            query[kSecAttrAccount as String] = key
        }
        if let data = data {
            query[kSecValueData as String] = data
        }
        if let accessGroup = self.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    func getOneQuery(byKey key: String) -> [String: Any] {
        var query = baseQuery(withKey: key)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return query
    }

    func setQuery(forKey key: String, data: Data) -> [String: Any] {
        var query = baseQuery(withKey: key, data: data)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return query
    }
}

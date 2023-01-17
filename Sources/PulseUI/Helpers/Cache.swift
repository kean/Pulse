// The MIT License (MIT)
//
// Copyright (c) 2015-2023 Alexander Grebenyuk (github.com/kean).

import Foundation

#if os(iOS) || os(tvOS)
import UIKit.UIApplication
#endif

// Internal memory-cache implementation.
final class Cache<Key: Hashable, Value>: @unchecked Sendable {
    // Can't use `NSCache` because it is not LRU

    struct Configuration {
        var costLimit: Int
        var countLimit: Int
        var entryCostLimit: Double
    }

    private let configuration: Configuration
    private var _totalCost = 0
    private var map = [Key: LinkedList<Entry>.Node]()
    private let list = LinkedList<Entry>()
    private let lock = NSLock()
    private let memoryPressure: DispatchSourceMemoryPressure
    private var notificationObserver: AnyObject?

    init(costLimit: Int, countLimit: Int) {
        self.configuration = Configuration(costLimit: costLimit, countLimit: countLimit, entryCostLimit: 0.1)

        self.memoryPressure = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        self.memoryPressure.setEventHandler { [weak self] in
            self?.removeAllCachedValues()
        }
        self.memoryPressure.resume()

#if os(iOS) || os(tvOS)
        self.registerForEnterBackground()
#endif
    }

    deinit {
        memoryPressure.cancel()
    }

#if os(iOS) || os(tvOS)
    private func registerForEnterBackground() {
        notificationObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            self?.clearCacheOnEnterBackground()
        }
    }
#endif

    func value(forKey key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }

        guard let node = map[key] else {
            return nil
        }

        // bubble node up to make it last added (most recently used)
        list.remove(node)
        list.append(node)

        return node.value.value
    }

    func set(_ value: Value, forKey key: Key, cost: Int = 0) {
        lock.lock()
        defer { lock.unlock() }

        // Take care of overflow or cache size big enough to fit any
        // reasonable content (and also of costLimit = Int.max).
        let sanitizedEntryLimit = max(0, min(configuration.entryCostLimit, 1))
        guard configuration.costLimit > 2147483647 || cost < Int(sanitizedEntryLimit * Double(configuration.costLimit)) else {
            return
        }

        let entry = Entry(value: value, key: key, cost: cost)
        _add(entry)
        _trim() // _trim is extremely fast, it's OK to call it each time
    }

    @discardableResult
    func removeValue(forKey key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }

        guard let node = map[key] else {
            return nil
        }
        _remove(node: node)
        return node.value.value
    }

    private func _add(_ element: Entry) {
        if let existingNode = map[element.key] {
            _remove(node: existingNode)
        }
        map[element.key] = list.append(element)
        _totalCost += element.cost
    }

    private func _remove(node: LinkedList<Entry>.Node) {
        list.remove(node)
        map[node.value.key] = nil
        _totalCost -= node.value.cost
    }

    func removeAllCachedValues() {
        lock.lock()
        defer { lock.unlock() }

        map.removeAll()
        list.removeAllElements()
        _totalCost = 0
    }

    private dynamic func clearCacheOnEnterBackground() {
        // Remove most of the stored items when entering background.
        // This behavior is similar to `NSCache` (which removes all
        // items). This feature is not documented and may be subject
        // to change in future Nuke versions.
        lock.lock()
        defer { lock.unlock() }

        _trim(toCost: Int(Double(configuration.costLimit) * 0.1))
        _trim(toCount: Int(Double(configuration.countLimit) * 0.1))
    }

    private func _trim() {
        _trim(toCost: configuration.costLimit)
        _trim(toCount: configuration.countLimit)
    }

    private func _trim(toCost limit: Int) {
        _trim(while: { _totalCost > limit })
    }

    private func _trim(toCount limit: Int) {
        _trim(while: { map.count > limit })
    }

    private func _trim(while condition: () -> Bool) {
        while condition(), let node = list.first { // least recently used
            _remove(node: node)
        }
    }

    private struct Entry {
        let value: Value
        let key: Key
        let cost: Int
    }
}

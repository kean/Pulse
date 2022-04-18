// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation

#if os(iOS) || os(tvOS)
import UIKit
#endif

final class Cache<Key: Hashable, Value> {
    // Can't use `NSCache` because it is not LRU

    private var map = [Key: LinkedList<Entry>.Node]()
    private let list = LinkedList<Entry>()
    private let lock = NSLock()
    private let memoryPressure: DispatchSourceMemoryPressure
    private weak var removeExpiredTimer: Timer?

    var costLimit: Int {
        didSet { lock.sync(_trim) }
    }

    var countLimit: Int {
        didSet { lock.sync(_trim) }
    }

    private(set) var totalCost = 0
    var ttl: TimeInterval = 0

    var totalCount: Int {
        map.count
    }

    init(costLimit: Int, countLimit: Int, isTTLCeanupEnabled: Bool = true) {
        self.costLimit = costLimit
        self.countLimit = countLimit
        self.memoryPressure = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        self.memoryPressure.setEventHandler { [weak self] in
            self?.removeAll()
        }
        self.memoryPressure.resume()

        removeExpiredTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.removeExpired()
        }

        #if os(iOS) || os(tvOS)
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(didEnterBackground),
                           name: UIApplication.didEnterBackgroundNotification,
                           object: nil)
        #endif
    }

    deinit {
        memoryPressure.cancel()
    }

    func removeExpired() {
        lock.lock(); defer { lock.unlock() }

        for node in map.values {
            if node.value.isExpired {
                _remove(node: node)
            }
        }
    }

    func value(forKey key: Key) -> Value? {
        lock.lock(); defer { lock.unlock() }

        guard let node = map[key] else {
            return nil
        }

        guard !node.value.isExpired else {
            _remove(node: node)
            return nil
        }

        // bubble node up to make it last added (most recently used)
        list.remove(node)
        list.append(node)

        return node.value.value
    }

    func set(_ value: Value, forKey key: Key, cost: Int = 0, ttl: TimeInterval? = nil) {
        lock.lock(); defer { lock.unlock() }

        let ttl = ttl ?? self.ttl
        let expiration = ttl == 0 ? nil : (Date() + ttl)
        let entry = Entry(value: value, key: key, cost: cost, expiration: expiration)
        _add(entry)
        _trim() // _trim is extremely fast, it's OK to call it each time
    }

    @discardableResult
    func removeValue(forKey key: Key) -> Value? {
        lock.lock(); defer { lock.unlock() }

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
        totalCost += element.cost
    }

    private func _remove(node: LinkedList<Entry>.Node) {
        list.remove(node)
        map[node.value.key] = nil
        totalCost -= node.value.cost
    }

    @objc
    dynamic func removeAll() {
        lock.sync {
            map.removeAll()
            list.removeAll()
            totalCost = 0
        }
    }

    private func _trim() {
        _trim(toCost: costLimit)
        _trim(toCount: countLimit)
    }

    @objc
    private dynamic func didEnterBackground() {
        // Remove most of the stored items when entering background.
        // This behavior is similar to `NSCache` (which removes all
        // items). This feature is not documented and may be subject
        // to change in future Nuke versions.
        lock.sync {
            _trim(toCost: Int(Double(costLimit) * 0.1))
            _trim(toCount: Int(Double(countLimit) * 0.1))
        }
    }

    func trim(toCost limit: Int) {
        lock.sync { _trim(toCost: limit) }
    }

    private func _trim(toCost limit: Int) {
        _trim(while: { totalCost > limit })
    }

    func trim(toCount limit: Int) {
        lock.sync { _trim(toCount: limit) }
    }

    private func _trim(toCount limit: Int) {
        _trim(while: { totalCount > limit })
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
        let expiration: Date?
        var isExpired: Bool {
            guard let expiration = expiration else {
                return false
            }
            return expiration.timeIntervalSinceNow < 0
        }
    }
}

/// A doubly linked list.
final class LinkedList<Element> {
    // first <-> node <-> ... <-> last
    private(set) var first: Node?
    private(set) var last: Node?

    deinit {
        removeAll()

        #if TRACK_ALLOCATIONS
        Allocations.decrement("LinkedList")
        #endif
    }

    init() {
        #if TRACK_ALLOCATIONS
        Allocations.increment("LinkedList")
        #endif
    }

    var isEmpty: Bool {
        last == nil
    }

    /// Adds an element to the end of the list.
    @discardableResult
    func append(_ element: Element) -> Node {
        let node = Node(value: element)
        append(node)
        return node
    }

    /// Adds a node to the end of the list.
    func append(_ node: Node) {
        if let last = last {
            last.next = node
            node.previous = last
            self.last = node
        } else {
            last = node
            first = node
        }
    }

    func remove(_ node: Node) {
        node.next?.previous = node.previous // node.previous is nil if node=first
        node.previous?.next = node.next // node.next is nil if node=last
        if node === last {
            last = node.previous
        }
        if node === first {
            first = node.next
        }
        node.next = nil
        node.previous = nil
    }

    func removeAll() {
        // avoid recursive Nodes deallocation
        var node = first
        while let next = node?.next {
            node?.next = nil
            next.previous = nil
            node = next
        }
        last = nil
        first = nil
    }

    final class Node {
        let value: Element
        fileprivate var next: Node?
        fileprivate var previous: Node?

        init(value: Element) {
            self.value = value
        }
    }
}

extension NSLock {
    func sync<T>(_ closure: () -> T) -> T {
        lock()
        defer { unlock() }
        return closure()
    }
}

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

private let commonKeyPrefix = "com-github-com-kean-pulse__"

final class ConsoleSettings: PersistentSettings {
    static let shared = ConsoleSettings()

    @UserDefault("console-line-limit")
    var lineLimit: Int = 4

    @UserDefaultRaw("sharing-time-range")
    var sharingTimeRange: SharingTimeRange = .all

    @UserDefault("link-detection")
    var isLinkDetectionEnabled = false

    @UserDefaultRaw("sharing-level")
    var sharingLevel: LoggerStore.Level = .trace

    @UserDefaultRaw("sharing-output")
    var sharingOutput: ShareStoreOutput = .store
}

final class ConsoleTextViewSettings: PersistentSettings {
    static let shared = ConsoleTextViewSettings()

    @UserDefaultRaw("console-text-view__color-mode")
    var colorMode = TextRenderer.ColorMode.automatic

    @UserDefault("console-text-view__request-headers")
    var showsRequestHeaders = false

    @UserDefault("console-text-view__response-body-shown")
    var showsResponseBody = true

    @UserDefault("console-text-view__response-headers")
    var showsResponseHeaders = false

    @UserDefault("console-text-view__request-body-shown")
    var showsRequestBody = true

    func reset() {
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            if key.hasPrefix(commonKeyPrefix + "console-text-view__") {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}

class PersistentSettings: ObservableObject {
    private var cancellables: [AnyCancellable] = []

    init() {
        let properties = Mirror(reflecting: self).children
            .compactMap { $0.value as? UserDefaultProtocol }
        ConsoleSettings.onChange(of: properties).sink { [objectWillChange] in
            objectWillChange.send()
        }.store(in: &cancellables)
    }

    private static func onChange(of properties: [UserDefaultProtocol]) -> AnyPublisher<Void, Never> {
        Publishers.MergeMany(properties.map(\.didUpdate)).eraseToAnyPublisher()
    }
}

@propertyWrapper
final class UserDefault<Value: UserDefaultSupportedValue>: UserDefaultProtocol, DynamicProperty {
    private let key: String
    private let defaultValue: Value
    private let container: UserDefaults = .standard
    private let publisher = PassthroughSubject<Value, Never>()
    private let observer: AnyObject?

    init(wrappedValue value: Value, _ key: String) {
        self.key = commonKeyPrefix + key
        self.defaultValue = value
        self.observer = UserDefaultsObserver(key: self.key, onChange: { [publisher] _, newValue in
            if let newValue = newValue as? Optional<Value>, newValue == nil {
                publisher.send(value) // Send default value
            } else {
                guard let value = newValue as? Value else {
                    return assertionFailure()
                }
                publisher.send(value)
            }
        })
    }

    var wrappedValue: Value {
        get {
            (container.object(forKey: key) as? Value) ?? defaultValue
        }
        set {
            container.set(newValue, forKey: key)
        }
    }

    var projectedValue: AnyPublisher<Value, Never> {
        publisher.eraseToAnyPublisher()
    }

    var didUpdate: AnyPublisher<Void, Never> {
        publisher.map { _ in () }.eraseToAnyPublisher()
    }
}

protocol UserDefaultSupportedValue {}

extension Bool: UserDefaultSupportedValue {}
extension Int: UserDefaultSupportedValue {}
extension Int16: UserDefaultSupportedValue {}
extension String: UserDefaultSupportedValue {}

@propertyWrapper
final class UserDefaultRaw<Value: RawRepresentable>: UserDefaultProtocol, DynamicProperty {
    private let key: String
    private let defaultValue: Value
    private let container: UserDefaults = .standard
    private let publisher = PassthroughSubject<Value, Never>()
    private let observer: AnyObject?

    init(wrappedValue value: Value, _ key: String) {
        self.key = commonKeyPrefix + key
        self.defaultValue = value
        self.observer = UserDefaultsObserver(key: self.key, onChange: { [publisher] _, newValue in
            if let newValue = newValue as? Optional<Value>, newValue == nil {
                publisher.send(value) // Send default value
            } else {
                guard let rawValue = newValue as? Value.RawValue else {
                    return assertionFailure()
                }
                guard let value = Value(rawValue: rawValue) else {
                    return
                }
                publisher.send(value)
            }
        })
    }

    var wrappedValue: Value {
        get {
            (container.object(forKey: key) as? Value.RawValue)
                .flatMap(Value.init) ?? defaultValue
        }
        set {
            container.set(newValue.rawValue, forKey: key)
        }
    }

    var projectedValue: AnyPublisher<Value, Never> {
        publisher.eraseToAnyPublisher()
    }

    var didUpdate: AnyPublisher<Void, Never> {
        publisher.map { _ in () }.eraseToAnyPublisher()
    }
}

protocol UserDefaultProtocol {
    var didUpdate: AnyPublisher<Void, Never> { get }
}

private final class UserDefaultsObserver: NSObject {
    let key: String
    private var onChange: (Any, Any) -> Void

    init(key: String, onChange: @escaping (Any, Any) -> Void) {
        self.onChange = onChange
        self.key = key
        super.init()
        UserDefaults.standard.addObserver(self, forKeyPath: key, options: [.new], context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let change = change, object != nil, keyPath == key else { return }
        onChange(change[.oldKey] as Any, change[.newKey] as Any)
    }

    deinit {
        UserDefaults.standard.removeObserver(self, forKeyPath: key, context: nil)
    }
}

// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

final class ConsoleSettings: ObservableObject {
    static let shared = ConsoleSettings()

    @UserDefault("console-line-limit")
    var lineLimit: Int = 4

    @UserDefaultRaw("sharing-time-range")
    var sharingTimeRange: SharingTimeRange = .currentSession

    @UserDefaultRaw("sharing-level")
    var sharingLevel: LoggerStore.Level = .trace

    @UserDefaultRaw("sharing-output")
    var sharingOutput: ShareStoreOutput = .store

    private var cancellables: [AnyCancellable] = []

    init() {
        let properties = Mirror(reflecting: self).children
            .compactMap { $0.value as? UserDefaultProtocol }
        print(properties)
        ConsoleSettings.onChange(of: properties).sink { [objectWillChange] in
            objectWillChange.send()
        }.store(in: &cancellables)
    }

    private static func onChange(of properties: [UserDefaultProtocol]) -> AnyPublisher<Void, Never> {
        Publishers.MergeMany(properties.map(\.didUpdate)).eraseToAnyPublisher()
    }
}

@propertyWrapper
struct UserDefault<Value: UserDefaultSupportedValue>: UserDefaultProtocol, DynamicProperty {
    private let key: String
    private let defaultValue: Value
    private let container: UserDefaults = .standard
    private let publisher = PassthroughSubject<Value, Never>()

    init(wrappedValue value: Value, _ key: String) {
        self.key = "com-github-com-kean-pulse__" + key
        self.defaultValue = value
    }

    var wrappedValue: Value {
        get {
            (container.object(forKey: key) as? Value) ?? defaultValue
        }
        set {
            container.set(newValue, forKey: key)
            publisher.send(newValue)
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

extension Int: UserDefaultSupportedValue {}
extension Int16: UserDefaultSupportedValue {}
extension String: UserDefaultSupportedValue {}

@propertyWrapper
struct UserDefaultRaw<Value: RawRepresentable>: UserDefaultProtocol, DynamicProperty {
    private let key: String
    private let defaultValue: Value
    private let container: UserDefaults = .standard
    private let publisher = PassthroughSubject<Value, Never>()

    init(wrappedValue value: Value, _ key: String) {
        self.key = "com-github-com-kean-pulse__" + key
        self.defaultValue = value
    }

    var wrappedValue: Value {
        get {
            (container.object(forKey: key) as? Value.RawValue)
                .flatMap(Value.init) ?? defaultValue
        }
        set {
            container.set(newValue.rawValue, forKey: key)
            publisher.send(newValue)
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

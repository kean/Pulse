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

    // MARK: ConsoleTextView

    @UserDefault("console-text-view__order-ascending")
    var isConsoleTextViewOrderAscending = false

    @UserDefault("console-text-view__responses-collapsed")
    var isConsoleTextViewResponsesCollaped = true

    @UserDefault("console-text-view__is-monochrome")
    var isConsoleTextViewMonochrome = true

    @UserDefault("console-text-view__syntax-highlighting")
    var isConsoleTextViewSyntaxHighlightingEnabled = true

    @UserDefault("console-text-view__link-detection")
    var isConsoleTextViewLinkDetection = true

    @UserDefault("console-text-view__view-font-size")
    var consoleTextViewFontSize = 15

    @UserDefault("console-text-view__monospaced-font-size")
    var consoleTextViewMonospacedFontSize = 12

    @UserDefault("console-text-view__request-headers")
    var isConsoleTextViewRequestHeadersShown = false

    @UserDefault("console-text-view__response-body-shown")
    var isConsoleTextViewResponseBodyShown = true

    @UserDefault("console-text-view__response-headers")
    var isConsoleTextViewResponseHeadersShown = false

    @UserDefault("console-text-view__request-body-shown")
    var isConsoleTextViewRequestBodyShown = true

    func resetConsoleTextViewSettings() {
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            if key.hasPrefix(commonKeyPrefix + "console-text-view__") {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

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
final class UserDefault<Value: UserDefaultSupportedValue>: UserDefaultProtocol, DynamicProperty {
    private let key: String
    private let defaultValue: Value
    private let container: UserDefaults = .standard
    private let publisher = PassthroughSubject<Value, Never>()

    init(wrappedValue value: Value, _ key: String) {
        self.key = commonKeyPrefix + key
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

private let commonKeyPrefix = "com-github-com-kean-pulse__"

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

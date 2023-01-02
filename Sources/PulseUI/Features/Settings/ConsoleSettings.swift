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

    @UserDefault("text-view-order-ascending")
    var isTextViewOrderAscending = false

    @UserDefault("text-view-responses-collapsed")
    var isTextViewResponsesCollaped = true

    @UserDefault("console-text-view-is-monochrome")
    var isConsoleTextViewMonochrome = true

    @UserDefault("console-text-view-syntax-highlighting")
    var isConsoleTextViewSyntaxHighlightingEnabled = true

    @UserDefault("console-text-view-link-detection")
    var isConsoleTextViewLinkDetection = true

//    var networkContent: NetworkContent = [.errorDetails, .requestBody, .responseBody]
//    var fontSize: CGFloat = 15
//    var monospacedFontSize: CGFloat = 12
//}
//
//struct NetworkContent: OptionSet {
//    let rawValue: Int16
//
//    init(rawValue: Int16) {
//        self.rawValue = rawValue
//    }
//
//    static let errorDetails = NetworkContent(rawValue: 1 << 0)
//    static let originalRequestHeaders = NetworkContent(rawValue: 1 << 2)
//    static let currentRequestHeaders = NetworkContent(rawValue: 1 << 3)
//    static let requestOptions = NetworkContent(rawValue: 1 << 4)
//    static let requestBody = NetworkContent(rawValue: 1 << 5)
//    static let responseHeaders = NetworkContent(rawValue: 1 << 6)
//    static let responseBody = NetworkContent(rawValue: 1 << 7)

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

// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

// TODO: Switch to AppStorage on iOS 14
public final class ConsoleSettings: ObservableObject {
    public static let shared = ConsoleSettings()

    @Published public var lineLimit: Int

    private var cancellables: [AnyCancellable] = []

    init() {
        lineLimit = UserDefaults.lineLimit ?? 4

        $lineLimit.sink { UserDefaults.lineLimit = $0 }.store(in: &cancellables)
    }
}

@propertyWrapper
struct UserDefault<Value> {
    var wrappedValue: Value? {
        get { storage.value(forKey: key) as? Value }
        set { storage.setValue(newValue, forKey: key) }
    }

    private let key: String
    private let storage: UserDefaults

    init(_ key: String, storage: UserDefaults = .standard) {
        self.key = key
        self.storage = storage
    }
}

extension UserDefaults {
    @UserDefault("\(keyPrefix)_console-line-limit")
    static var lineLimit: Int?
}

private let keyPrefix = "com-github-com-kean-pulse"

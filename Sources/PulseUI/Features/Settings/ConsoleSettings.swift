// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

// TODO: Switch to AppStorage on iOS 14
public final class ConsoleSettings: ObservableObject {
    public static let shared = ConsoleSettings()

    @Published public var lineLimit = 4

    private var cancellables: [AnyCancellable] = []

    init() {
        lineLimit = UserDefaults.standard.integer(forKey: .lineLimitKey)
        if lineLimit == 0 { lineLimit = 4 }

        $lineLimit.sink {
            UserDefaults.standard.set($0, forKey: .lineLimitKey) }
        .store(in: &cancellables)
    }
}

private extension String {
    static let lineLimitKey = "\(keyPrefix)console-line-limit"
}

private let keyPrefix = "com-github-com-kean-pulse__"

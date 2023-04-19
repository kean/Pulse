// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

/// Gets incremented every time it is set to `true` and decremented when
/// it is set to `false`.
///
/// - note: It was added as a workaround for an issue with SwiftUI
/// lifecycle events where if you change the identity and reload the
/// same view, it receives the events in the following order:
///
/// - onAppear for view #1
/// - onAppear for view #2
/// - onDisappear for view #1
@propertyWrapper struct Counter {
    var value = 0

    var wrappedValue: Bool {
        get {
            value > 0
        }
        set {
            value += newValue ? 1 : -1
        }
    }
}

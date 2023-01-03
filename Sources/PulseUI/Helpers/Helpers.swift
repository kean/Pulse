// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation

/// Works like lazy, but can be reset.
@propertyWrapper final class LazyReset<T> {
    private let _init: () -> T
    private var _wrappedValue: T?

    var wrappedValue: T {
        get {
            if _wrappedValue == nil {
                _wrappedValue = _init()
            }
            return _wrappedValue!
        }
    }

    init(_ closure: @escaping () -> T) {
        self._init = closure
    }

    func reset() {
        _wrappedValue = nil
    }
}

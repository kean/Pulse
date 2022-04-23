// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import PulseCore

#warning("TODO: remove")
@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
struct AppContext {
    let store: LoggerStore
    var share: ConsoleShareService { .init(store: store )}
}

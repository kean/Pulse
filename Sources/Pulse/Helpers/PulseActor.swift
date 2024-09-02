// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

/// A global actor on which Pulse subsystems are syncrhonized.
@globalActor
struct PulseActor {
    actor PulseActor { }
    static let shared = PulseActor()
}

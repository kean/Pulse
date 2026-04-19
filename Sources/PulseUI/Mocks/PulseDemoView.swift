// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if DEBUG || STANDALONE_PULSE_APP

import SwiftUI
import Pulse

/// A demo harness that shows ``ConsoleView`` backed by ``LoggerStore/mock``
/// and ``MockConsoleDelegate``. Used by the "Pulse Demo" Xcode target to
/// exercise the `PulseUI` surface without standing up a real logger store.
///
/// Set the `PULSE_STORE_URL` environment variable (in the "Pulse Demo"
/// scheme) to a path or `file://` URL of a `.pulse` package to open that
/// store instead of the built-in mock — useful for reproducing issues
/// against a real capture.
///
/// Additional variants (e.g. a sessions-only view, a search harness, or a
/// network-only console) can be added here as needed.
@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
public struct PulseDemoView: View {
    public init() {}

    public var body: some View {
#if !os(macOS)
        ConsoleView(store: PulseDemoView.store, delegate: MockConsoleDelegate.shared)
#endif
    }

    private static var store: LoggerStore {
        if let value = ProcessInfo.processInfo.environment["PULSE_STORE_URL"],
           !value.isEmpty {
            let url = URL(string: value).flatMap { $0.scheme == nil ? nil : $0 }
                ?? URL(fileURLWithPath: (value as NSString).expandingTildeInPath)
            do {
                return try LoggerStore(storeURL: url, options: [.readonly])
            } catch {
                assertionFailure("PULSE_STORE_URL set but failed to open \(url): \(error)")
            }
        }
        return .mock
    }
}

#endif

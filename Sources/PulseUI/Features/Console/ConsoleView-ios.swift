// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS)

import SwiftUI
import CoreData
import Pulse
import Combine
#if os(iOS)
import WatchConnectivity
#endif

public struct ConsoleView: View {
    @StateObject private var environment: ConsoleEnvironment // Never reloads
    @Environment(\.presentationMode) private var presentationMode
    private var isCloseButtonHidden = false

    init(environment: ConsoleEnvironment) {
        _environment = StateObject(wrappedValue: environment)
    }

    public var body: some View {
        if #available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *) {
            contents
        } else {
            PlaceholderView(imageName: "xmark.octagon", title: "Unsupported", subtitle: "Pulse requires iOS 18 or later").padding()
        }
    }

    @available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
    private var contents: some View {
        ConsoleListView()
#if os(iOS) || os(visionOS)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    if !isCloseButtonHidden && presentationMode.wrappedValue.isPresented {
                        makeButton(role: .close) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
#endif
            .injecting(environment)
    }

    /// Changes the default close button visibility.
    public func closeButtonHidden(_ isHidden: Bool = true) -> ConsoleView {
        var copy = self
        copy.isCloseButtonHidden = isHidden
        return copy
    }
}

#if DEBUG
@available(iOS 18, macOS 15, visionOS 1, *)
#Preview("Console") {
    NavigationStack {
        ConsoleView(store: LoggerStore.mock, delegate: MockConsoleDelegate.shared)
    }
#if os(macOS)
    .frame(width: 500, height: 600)
#endif
}
#endif

#endif

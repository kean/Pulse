// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import SwiftUI
import CoreData
import Combine

#if os(watchOS) || os(tvOS)

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct SessionsView: View {
    @State private var selection: Set<UUID> = []
    @State private var sharedSessions: SelectedSessionsIDs?

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \LoggerSessionEntity.createdAt, ascending: false)])
    private var sessions: FetchedResults<LoggerSessionEntity>

    @EnvironmentObject private var environment: ConsoleEnvironment
    @EnvironmentObject private var filters: ConsoleFiltersViewModel
    @Environment(\.store) private var store
    @Environment(\.router) private var router

    var body: some View {
        if store.version < LoggerStore.Version(3, 6, 0) {
            PlaceholderView(imageName: "questionmark.app", title: "Unsupported", subtitle: "This feature requires a store created by Pulse version 3.6.0 or higher").padding()
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        SessionListView(selection: $selection, sharedSessions: $sharedSessions)
            .navigationTitle("Sessions")
            .onChange(of: selection) { _, newValue in
                showInConsole(sessions: newValue)
            }
    }

    private func showInConsole(sessions: Set<UUID>) {
        filters.sessions = sessions
        router.isShowingSessions = false
    }
}

#if DEBUG
@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
#Preview {
    NavigationView {
        SessionsView()
            .injecting(ConsoleEnvironment(store: LoggerStore.mock))
    }
}
#endif

#endif

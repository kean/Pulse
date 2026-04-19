// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import SwiftUI
import CoreData
import Combine

#if os(iOS) || os(visionOS)

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct SessionsView: View {
    @State private var selection: Set<UUID> = []
    @State private var sharedSessions: SelectedSessionsIDs?

    @State private var editMode: EditMode = .inactive

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
            .environment(\.editMode, $editMode)
            .onChange(of: selection) { _, newValue in
                guard !editMode.isEditing, !newValue.isEmpty else { return }
                showInConsole(sessions: newValue)
            }
            .navigationTitle(editMode.isEditing ? "\(selection.count) Session\(selection.count % 10 == 1 ? "" : "s") Selected" : "Sessions")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                toolbar
            }
            .sheet(item: $sharedSessions) { sessions in
                NavigationView {
                    ShareStoreView(sessions: sessions.ids, onDismiss: { sharedSessions = nil })
                }.presentationDetents([.medium, .large])
            }
            .onAppear {
                if filters.sessions.count > 1 {
                    selection = filters.sessions
                    editMode = .active
                }
            }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if editMode.isEditing {
                Button("Done") {
                    showInConsole(sessions: selection)
                }
            } else {
                Button("Select") {
                    withAnimation {
                        selection = filters.sessions
                        editMode = .active
                    }
                }
            }
        }
        if editMode == .active {
            ToolbarItemGroup(placement: .bottomBar) {
                if !store.isReadonly {
                    Button(role: .destructive, action: {
                        store.removeSessions(withIDs: selection)
                        selection = []
                    }, label: { Image(systemName: "trash") })
                    .disabled(selection.isEmpty || store.currentSessionID.map { selection == [$0] } ?? false)
                }

                Spacer()

                let allIDs = Set(sessions.map(\.id))
                let isAllSelected = !allIDs.isEmpty && selection.intersection(allIDs).count == allIDs.count
                Button(isAllSelected ? "Deselect All" : "Select All") {
                    if isAllSelected {
                        selection.subtract(allIDs)
                    } else {
                        selection.formUnion(allIDs)
                    }
                }

                Spacer()

                Button(action: { sharedSessions = SelectedSessionsIDs(ids: selection) }, label: {
                    Image(systemName: "square.and.arrow.up")
                })
                .disabled(selection.isEmpty)
            }
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

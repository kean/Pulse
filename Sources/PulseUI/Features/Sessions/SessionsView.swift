// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import SwiftUI
import CoreData
import Combine

#if os(iOS) || os(macOS) || os(visionOS)

@available(iOS 15, macOS 13, visionOS 1.0, *)
struct SessionsView: View {
    @State private var selection: Set<UUID> = []
    @State private var sharedSessions: SelectedSessionsIDs?

#if os(iOS) || os(visionOS)
    @State private var editMode: EditMode = .inactive
#endif

    @EnvironmentObject private var environment: ConsoleEnvironment
    @EnvironmentObject private var filters: ConsoleFiltersViewModel
    @Environment(\.store) private var store
    @Environment(\.router) private var router

    var body: some View {
        if let version = Version(store.version), version < Version(3, 6, 0) {
            PlaceholderView(imageName: "questionmark.app", title: "Unsupported", subtitle: "This feature requires a store created by Pulse version 3.6.0 or higher").padding()
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        list
#if os(iOS) || os(visionOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(editMode.isEditing ? "Done" : "Edit") {
                        withAnimation {
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    if editMode == .active {
                        bottomBar
                    }
                }
            }
            .sheet(item: $sharedSessions) { sessions in
                NavigationView {
                    ShareStoreView(sessions: sessions.ids, onDismiss: { sharedSessions = nil })
                }.backport.presentationDetents([.medium, .large])
            }
#else
            .popover(item: $sharedSessions, arrowEdge: .leading) { sessions in
                ShareStoreView(sessions: sessions.ids, onDismiss: { sharedSessions = nil })
                    .frame(width: 240).fixedSize()
            }
#endif
    }

    private var list: some View {
        SessionListView(selection: $selection, sharedSessions: $sharedSessions)
#if os(iOS) || os(visionOS)
            .environment(\.editMode, $editMode)
            .onChange(of: selection) {
                guard !editMode.isEditing, !$0.isEmpty else { return }
                showInConsole(sessions: $0)
            }
#else
            .contextMenu(forSelectionType: UUID.self, menu: contextMenu)
            .onChange(of: selection) {
                guard filters.criteria.shared.sessions.selection != $0 else { return }
                filters.select(sessions: $0)
            }
#endif
    }

#if os(iOS) || os(visionOS)
    var bottomBar: some View {
        HStack {
            Button(role: .destructive, action: {
                store.removeSessions(withIDs: selection)
                selection = []
            }, label: { Image(systemName: "trash") })
            .disabled(selection.isEmpty || selection == [store.session.id])

            Spacer()

            // It should ideally be done using stringsdict, but Pulse
            // doesn't support localization.
            if selection.count % 10 == 1 {
                Text("\(selection.count) Session Selected")
            } else {
                Text("\(selection.count) Sessions Selected")
            }

            Spacer()

            Button(action: { sharedSessions = SelectedSessionsIDs(ids: selection) }, label: {
                Image(systemName: "square.and.arrow.up")
            })
            .disabled(selection.isEmpty)

            Menu(content: {
                Button("Show in Console") {
                    showInConsole(sessions: selection)
                }.disabled(selection.isEmpty)
            }, label: {
                Image(systemName: "ellipsis.circle")
            })
        }
    }

    private func showInConsole(sessions: Set<UUID>) {
        filters.select(sessions: sessions)
        router.isShowingSessions = false
    }
#endif
    
#if os(macOS)
    @ViewBuilder
    private func contextMenu(for selection: Set<UUID>) -> some View {
        Button(action: { sharedSessions = SelectedSessionsIDs(ids: selection) }, label: {
            Label("Share", systemImage: "square.and.arrow.up")
        })
        .disabled(selection.isEmpty)

        if !(store.options.contains(.readonly)) {
            Button(role: .destructive, action: {
                store.removeSessions(withIDs: selection)
                self.selection = []
            }, label: { Label("Remove", systemImage: "trash") })
        }
    }
#endif
}

#if DEBUG
@available(iOS 15.0, macOS 13, visionOS 1.0, *)
struct Previews_SessionsView_Previews: PreviewProvider {
    static let environment = ConsoleEnvironment(store: .mock)

    static var previews: some View {
#if os(iOS) || os(visionOS)
        NavigationView {
            SessionsView()
                .injecting(environment)
        }
#else
        SessionsView()
            .injecting(environment)
#endif
    }
}
#endif

#endif

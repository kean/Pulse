// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import SwiftUI
import CoreData
import Combine

#if os(iOS) || os(macOS)

#warning("add more button with show in console (and something else?)")
#warning("on single selection show session in console")
#warning("preselect session on macOS too")
#warning("add sharing on macOS too")
#warning("is select all in the right place?")
@available(macOS 13, *)
struct ConsoleSessionsView: View {
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \LoggerSessionEntity.createdAt, ascending: false)])
    private var sessions: FetchedResults<LoggerSessionEntity>

    @State private var filterTerm = ""
    @State private var selection: Set<UUID> = []
    @State private var limit = 12
    @State private var isSharing = false
    @State private var editMode: EditMode = .inactive

    @EnvironmentObject private var consoleViewModel: ConsoleViewModel
    @Environment(\.store) private var store

    var body: some View {
        if let version = Version(store.version), version < Version(3, 6, 0) {
            PlaceholderView(imageName: "questionmark.app", title: "Unsupported", subtitle: "This feature requires a store created by Pulse version 3.6.0 or higher").padding()
        } else if sessions.isEmpty {
            Text("No Recorded Session")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundColor(.secondary)
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
#if os(macOS)
            VStack {
                list
                HStack {
                    Spacer()
                    SearchBar(title: "Filter", imageName: "line.3.horizontal.decrease.circle", text: $filterTerm)
                        .frame(maxWidth: 220)
                }.padding(8)
            }
#else
            list.toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(editMode.isEditing ? "Done" : "Edit") {
                        withAnimation {
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    if editMode == .active {
                        ConsoleSessionBottomBar(selection: $selection, isSharing: $isSharing)
                    }
                }
            }
            .sheet(isPresented: $isSharing) {
                NavigationView {
                    ShareStoreView(sessions: selection, isPresented: $isSharing)
                }.backport.presentationDetents([.medium])
            }
#endif
    }

    private var list: some View {
        List(selection: $selection) {
            if !filterTerm.isEmpty {
                ForEach(getFilteredSessions(), id: \.id, content: ConsoleSessionCell.init)
            } else {
                if sessions.count > limit {
                    ForEach(sessions.prefix(limit), id: \.id, content: ConsoleSessionCell.init)
                    buttonShowPreviousSessions
                } else {
                    ForEach(sessions, id: \.id, content: ConsoleSessionCell.init)
                }
            }
        }
#if os(iOS)
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
        .backport.searchable(text: $filterTerm)
#else
        .listStyle(.inset)
        .backport.hideListContentBackground()
        .contextMenu(forSelectionType: UUID.self, menu: contextMenu)
        .onChange(of: selection) {
            guard consoleViewModel.searchCriteriaViewModel.criteria.shared.sessions.selection != $0 else { return }
            consoleViewModel.searchCriteriaViewModel.select(sessions: $0)
        }
#endif
    }

    @ViewBuilder
    private var buttonShowPreviousSessions: some View {
        Button("Show Previous Sessions") {
            limit = Int.max
        }
#if os(macOS)
        .buttonStyle(.link)
        .padding(.top, 8)
#else
        .buttonStyle(.plain)
        .foregroundColor(.blue)
#endif
    }
    
#if os(macOS)
    @ViewBuilder
    private func contextMenu(for selection: Set<UUID>) -> some View {
        if !store.isArchive {
            Button(role: .destructive, action: {
                store.removeSessions(withIDs: selection)
            }, label: { Text("Remove") })
        }
    }
#endif

    private func getFilteredSessions() -> [LoggerSessionEntity] {
        sessions.filter { $0.formattedDate.localizedCaseInsensitiveContains(filterTerm) }
    }
}

#if os(iOS)
private struct ConsoleSessionBottomBar: View {
    @Binding var selection: Set<UUID>
    @Binding var isSharing: Bool

    @Environment(\.store) private var store

    var body: some View {
        HStack {
            Button.destructive(action: {
                store.removeSessions(withIDs: selection)
            }, label: { Image(systemName: "trash") })
            .disabled(selection.isEmpty)

            Spacer()

            // It should ideally be done using stringsdict, but Pulse
            // doesn't support localization.
            if selection.count % 10 == 1 {
                Text("\(selection.count) Session Selected")
            } else {
                Text("\(selection.count) Sessions Selected")
            }

            Spacer()

            Button(action: { isSharing = true }, label: {
                Image(systemName: "square.and.arrow.up")
            })
            .disabled(selection.isEmpty)
        }
    }
}
#endif

struct ConsoleSessionCell: View {
    let session: LoggerSessionEntity

    @Environment(\.store) private var store

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(session.formattedDate)
                .fontWeight(store.session.id == session.id ? .medium : .regular)
                .lineLimit(1)
                .layoutPriority(1)
            Spacer()
            if let version = session.fullVersion {
                Text(version)
                    .lineLimit(1)
                    .frame(minWidth: 40)
#if os(macOS)
                    .foregroundColor(Color(UXColor.tertiaryLabelColor))
#else
                    .font(.subheadline)
                    .foregroundColor(.secondary)
#endif
            }
        }
        .listRowBackground(Color.clear)
        .tag(session.id)
    }
}

#if DEBUG
@available(iOS 15.0, macOS 13, *)
struct Previews_ConsoleSessionsView_Previews: PreviewProvider {
    static let viewModel = ConsoleViewModel(store: .mock)

    static var previews: some View {
#if os(iOS)
        NavigationView {
            ConsoleSessionsView()
                .background(ConsoleRouterView(viewModel: viewModel))
                .injectingEnvironment(viewModel)
        }
#else
        ConsoleSessionsView()
            .injectingEnvironment(viewModel)
#endif
    }
}
#endif

#endif

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import SwiftUI
import CoreData
import Combine

#if os(iOS) || os(macOS)

#warning("preselect session on macOS too")
#warning("add sharing on macOS too")
@available(macOS 13, *)
struct ConsoleSessionsView: View {
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \LoggerSessionEntity.createdAt, ascending: false)])
    private var sessions: FetchedResults<LoggerSessionEntity>

    @State private var filterTerm = ""
    @State private var selection: Set<UUID> = []
    @State private var sharedSessions: SharedSessions?
    @State private var isSharing = false
    @State private var editMode: EditMode = .inactive
    @State private var groupedSessions: [(Date, [LoggerSessionEntity])] = []

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
                .onAppear { refreshGroups() }
                .onChange(of: sessions.count) { _ in refreshGroups() }
        }
    }

    private func refreshGroups() {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: sessions) {
            let components = calendar.dateComponents([.day, .year, .month], from: $0.createdAt)
            return calendar.date(from: components) ?? $0.createdAt
        }
        self.groupedSessions = Array(groups.sorted(by: { $0.key > $1.key }))
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
                        bottomBar
                    }
                }
            }
            .sheet(item: $sharedSessions) { sessions in
                NavigationView {
                    ShareStoreView(sessions: sessions.ids, onDismiss: { sharedSessions = nil })
                }.backport.presentationDetents([.medium])
            }
#endif
    }

    private var list: some View {
        List(selection: $selection) {
            if !filterTerm.isEmpty {
                ForEach(getFilteredSessions(), id: \.id, content: makeCell)
            } else {
#if os(iOS)
                ForEach(groupedSessions, id: \.0) { group in
                    Section(header: makeHeader(for: group.0, sessions: group.1)) {
                        ForEach(group.1, id: \.id, content: makeCell)
                    }
                }
#else
                ForEach(sessions, id: \.id, content: makeCell)
#endif
            }
        }
#if os(iOS)
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
        .backport.searchable(text: $filterTerm)
        .onChange(of: selection) {
            guard !editMode.isEditing, !$0.isEmpty else { return }
            showInConsole(sessions: $0)
        }
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

    private func makeHeader(for startDate: Date, sessions: [LoggerSessionEntity]) -> some View {
        HStack {
            (Text(sectionTitleFormatter.string(from: startDate)) +
             Text(" (\(sessions.count))").foregroundColor(.secondary.opacity(0.5)))
            .font(.headline)
            .padding(.vertical, 6)

            if editMode.isEditing {
                Spacer()
                Button("Select All") {
                    selection.formUnion(Set(sessions.map(\.id)))
                }.font(.subheadline)
            }
        }
    }

    @ViewBuilder
    private func makeCell(for session: LoggerSessionEntity) -> some View {
        ConsoleSessionCell(session: session)
            .backport.swipeActions {
                Button(action: {
                    if session.id != store.session.id {
                        store.removeSessions(withIDs: [session.id])
                    }
                }, label: {
                    Label("Delete", systemImage: "trash")
                }).backport.tint(Color.red)

                Button(action: { sharedSessions = SharedSessions(ids: [session.id]) }) {
                    Label("Share", systemImage: "square.and.arrow.up.fill")
                }.backport.tint(.blue)
            }
    }

#if os(iOS)
    var bottomBar: some View {
        HStack {
            Button.destructive(action: {
                store.removeSessions(withIDs: selection)
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

            Button(action: { isSharing = true }, label: {
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
        consoleViewModel.searchCriteriaViewModel.select(sessions: sessions)
        consoleViewModel.router.isShowingSessions = false
    }
#endif
    
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
        sessions.filter { $0.formattedDate(isCompact: false).localizedCaseInsensitiveContains(filterTerm) }
    }
}

struct ConsoleSessionCell: View {
    let session: LoggerSessionEntity
    var isCompact = true

    @Environment(\.store) private var store
    @Environment(\.editMode) private var editMode

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(session.formattedDate(isCompact: isCompact))
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
        .listRowBackground((editMode?.wrappedValue.isEditing ?? false) ? Color.clear : nil)
        .tag(session.id)
    }
}

private struct SharedSessions: Hashable, Identifiable {
    var id: SharedSessions { self }
    let ids: Set<UUID>
}

private let sectionTitleFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .none
    formatter.doesRelativeDateFormatting = true
    return formatter
}()

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

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import SwiftUI
import CoreData
import Combine

#if os(iOS) || os(macOS)

struct SessionListView: View {
    @Binding var selection: Set<UUID>
    @Binding var sharedSessions: SelectedSessionsIDs?

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \LoggerSessionEntity.createdAt, ascending: false)])
    private var sessions: FetchedResults<LoggerSessionEntity>

    @State private var filterTerm = ""
    @State private var groupedSessions: [(Date, [LoggerSessionEntity])] = []

    @Environment(\.editMode) private var editMode
    @Environment(\.store) private var store

    var body: some View {
        if sessions.isEmpty {
            Text("No Recorded Session")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundColor(.secondary)
        } else {
            list
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
        .backport.searchable(text: $filterTerm)
#else
        .listStyle(.inset)
        .backport.hideListContentBackground()
        .contextMenu(forSelectionType: UUID.self, menu: contextMenu)
#endif
    }

    private func makeHeader(for startDate: Date, sessions: [LoggerSessionEntity]) -> some View {
        HStack {
            (Text(sectionTitleFormatter.string(from: startDate)) +
             Text(" (\(sessions.count))").foregroundColor(.secondary.opacity(0.5)))
            .font(.headline)
            .padding(.vertical, 6)

            if editMode?.wrappedValue.isEditing ?? false {
                Spacer()
                Button("Select All") {
                    selection.formUnion(Set(sessions.map(\.id)))
                }.font(.subheadline)
            }
        }
    }

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

                Button(action: { sharedSessions = .init(ids: [session.id]) }) {
                    Label("Share", systemImage: "square.and.arrow.up.fill")
                }.backport.tint(.blue)
            }
    }

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

struct SelectedSessionsIDs: Hashable, Identifiable {
    var id: SelectedSessionsIDs { self }
    let ids: Set<UUID>
}

private let sectionTitleFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .none
    formatter.doesRelativeDateFormatting = true
    return formatter
}()

#endif

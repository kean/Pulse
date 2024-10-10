// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import SwiftUI
import CoreData
import Combine

#if os(iOS) || os(visionOS)

@available(iOS 16, macOS 13, visionOS 1, *)
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
        VStack(spacing: 0) {
            if sessions.isEmpty {
                Text("No Recorded Sessions")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundColor(.secondary)
            } else {
                content
                    .onAppear { refreshGroups() }
                    .onChange(of: sessions.count) { _ in refreshGroups() }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        List(selection: $selection) {
            if !filterTerm.isEmpty {
                ForEach(getFilteredSessions(), id: \.id, content: makeCell)
            } else {
                ForEach(groupedSessions, id: \.0) { group in
                    Section(header: makeHeader(for: group.0, sessions: group.1)) {
                        ForEach(group.1, id: \.id, content: makeCell)
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $filterTerm)
    }

    private func refreshGroups() {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: sessions) {
            let components = calendar.dateComponents([.day, .year, .month], from: $0.createdAt)
            return calendar.date(from: components) ?? $0.createdAt
        }
        self.groupedSessions = Array(groups.sorted(by: { $0.key > $1.key }))
    }

    private func makeHeader(for startDate: Date, sessions: [LoggerSessionEntity]) -> some View {
        HStack {
            (Text(sectionTitleFormatter.string(from: startDate)) +
             Text(" (\(sessions.count))").foregroundColor(.secondary.opacity(0.5)))
            .font(.headline)
            .padding(.vertical, 6)

            if editMode?.wrappedValue.isEditing ?? false {
                Spacer()

                let ids = Set(sessions.map(\.id))
                let isAllSelected = selection.intersection(ids).count == ids.count
                Button(isAllSelected ? "Deselect All" : "Select All") {
                    if isAllSelected {
                        selection.subtract(ids)
                    } else {
                        selection.formUnion(ids)
                    }
                }.font(.subheadline)
            }
        }
    }

    @ViewBuilder
    private func makeCell(for session: LoggerSessionEntity) -> some View {
        ConsoleSessionCell(session: session, isCompact: filterTerm.isEmpty)
            .swipeActions {
                Button(action: {
                    if session.id != store.session.id {
                        store.removeSessions(withIDs: [session.id])
                    }
                }, label: {
                    Label("Delete", systemImage: "trash")
                }).tint(Color.red)

                Button(action: { sharedSessions = .init(ids: [session.id]) }) {
                    Label("Share", systemImage: "square.and.arrow.up.fill")
                }.tint(.blue)
            }
    }

    private func getFilteredSessions() -> [LoggerSessionEntity] {
        sessions.filter {
            $0.searchTags.contains(where: {
                $0.firstRange(of: filterTerm, options: [.caseInsensitive]) != nil
            })
        }
    }
}

private let sectionTitleFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .none
    formatter.doesRelativeDateFormatting = true
    return formatter
}()

#endif

package struct SelectedSessionsIDs: Hashable, Identifiable {
    package var id: SelectedSessionsIDs { self }
    package let ids: Set<UUID>

    package init(ids: Set<UUID>) {
        self.ids = ids
    }
}

@available(macOS 13, *)
package struct ConsoleSessionCell: View {
    let session: LoggerSessionEntity
    var isCompact = true

    @Environment(\.store) private var store
#if os(iOS) || os(visionOS)
    @Environment(\.editMode) private var editMode
#endif

    package init(session: LoggerSessionEntity, isCompact: Bool = true) {
        self.session = session
        self.isCompact = isCompact
    }

    package var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(session.formattedDate(isCompact: isCompact))
                .fontWeight(store.session.id == session.id ? .medium : .regular)
                .lineLimit(1)
                .foregroundColor(.primary)
                .layoutPriority(1)
            details
        }
        .tag(session.id)
#if os(iOS) || os(visionOS)
        .listRowBackground((editMode?.wrappedValue.isEditing ?? false) ? Color.clear : nil)
#endif
    }

    @ViewBuilder
    private var details: some View {
#if !os(watchOS)
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
#endif
    }
}

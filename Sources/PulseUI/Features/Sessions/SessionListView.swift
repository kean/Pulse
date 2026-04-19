// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import SwiftUI
import CoreData
import Combine

#if os(iOS) || os(visionOS) || os(watchOS) || os(tvOS)

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct SessionListView: View {
    @Binding var selection: Set<UUID>
    @Binding var sharedSessions: SelectedSessionsIDs?

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \LoggerSessionEntity.createdAt, ascending: false)])
    private var sessions: FetchedResults<LoggerSessionEntity>

    @State private var filterTerm = ""
    @State private var groupedSessions: [(Date, [LoggerSessionEntity])] = []
    @State private var messageCounts: [UUID: Int] = [:]
    @State private var isLoadingMessageCounts = true

#if !os(watchOS)
    @Environment(\.editMode) private var editMode
#endif
    @Environment(\.store) private var store
    @EnvironmentObject private var filters: ConsoleFiltersViewModel

    var body: some View {
        VStack(spacing: 0) {
            if sessions.isEmpty {
                Text("No Recorded Sessions")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundColor(.secondary)
            } else {
                list
                    .onAppear { refresh() }
                    .onChange(of: sessions.count) { refresh() }
                    .task {
                        while !Task.isCancelled {
                            try? await Task.sleep(for: .seconds(3))
                            fetchCurrentSessionCount()
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var list: some View {
#if os(watchOS)
        List {
            listContent
        }
        .searchable(text: $filterTerm)
#else
        List(selection: $selection) {
            listContent
        }
        .listStyle(.plain)
#if !os(tvOS)
        .searchable(text: $filterTerm)
#endif
#endif
    }

    @ViewBuilder
    private var listContent: some View {
        if !filterTerm.isEmpty {
            ForEach(getFilteredSessions(), id: \.id) { session in
                makeCell(for: session, number: nil)
            }
        } else {
            ForEach(groupedSessions, id: \.0) { group in
                Section(header: makeHeader(for: group.0, sessions: group.1)) {
                    ForEach(Array(group.1.enumerated()), id: \.element.id) { index, session in
                        makeCell(for: session, number: group.1.count - index)
                    }
                }
            }
        }
    }

    private func refresh() {
        refreshGroups()
        fetchMessageCounts()
    }

    private func refreshGroups() {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: sessions) {
            let components = calendar.dateComponents([.day, .year, .month], from: $0.createdAt)
            return calendar.date(from: components) ?? $0.createdAt
        }
        self.groupedSessions = Array(groups.sorted(by: { $0.key > $1.key }))
    }

    private func fetchMessageCounts() {
        let context = store.newBackgroundContext()
        context.perform {
            let request = NSFetchRequest<NSDictionary>(entityName: "LoggerMessageEntity")
            request.resultType = .dictionaryResultType
            request.propertiesToGroupBy = ["session"]
            let countDesc = NSExpressionDescription()
            countDesc.name = "count"
            countDesc.expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "session")])
            countDesc.expressionResultType = .integer64AttributeType
            request.propertiesToFetch = ["session", countDesc]
            let results = (try? context.fetch(request)) ?? []
            var counts: [UUID: Int] = [:]
            for result in results {
                if let session = result["session"] as? UUID,
                   let count = result["count"] as? Int {
                    counts[session] = count
                }
            }
            Task { @MainActor in
                self.messageCounts = counts
                self.isLoadingMessageCounts = false
            }
        }
    }

    private func fetchCurrentSessionCount() {
        guard let currentID = store.currentSessionID else { return }
        let context = store.newBackgroundContext()
        context.perform {
            let request = NSFetchRequest<LoggerMessageEntity>(entityName: "LoggerMessageEntity")
            request.predicate = NSPredicate(format: "session == %@", currentID as CVarArg)
            let count = (try? context.count(for: request)) ?? 0
            Task { @MainActor in
                self.messageCounts[currentID] = count
            }
        }
    }

    private func makeHeader(for startDate: Date, sessions: [LoggerSessionEntity]) -> some View {
        HStack {
            Text(sectionTitleFormatter.string(from: startDate))
            .font(.headline)
            .padding(.vertical, 6)

#if !os(watchOS)
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
#endif
        }
    }

    @ViewBuilder
    private func makeCell(for session: LoggerSessionEntity, number: Int?) -> some View {
        ConsoleSessionCell(
            session: session,
            isCompact: filterTerm.isEmpty,
            isSelected: isSessionSelected(session),
            sessionNumber: number,
            messageCount: messageCounts[session.id],
            isLoadingMessageCount: isLoadingMessageCounts
        )
#if !os(tvOS)
        .swipeActions(edge: .leading) {
            Button(action: { sharedSessions = .init(ids: [session.id]) }) {
                Label("Share", systemImage: "square.and.arrow.up.fill")
            }.tint(.blue)
        }
        .swipeActions(edge: .trailing) {
            if session.id == store.currentSessionID {
                Button(action: {
                    store.clearSessions(withIDs: [session.id])
                }, label: {
                    Label("Remove Logs", systemImage: "xmark.bin")
                }).tint(Color.red)
            } else {
                Button(action: {
                    store.removeSessions(withIDs: [session.id])
                }, label: {
                    Label("Delete", systemImage: "trash")
                }).tint(Color.red)
            }
        }
#endif
#if os(iOS) || os(macOS)
        .contextMenu {
            Button(action: { sharedSessions = .init(ids: [session.id]) }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            if session.id == store.currentSessionID {
                Button(role: .destructive, action: {
                    store.clearSessions(withIDs: [session.id])
                }) {
                    Label("Remove Logs", systemImage: "xmark.bin")
                }
            } else {
                Button(role: .destructive, action: {
                    store.removeSessions(withIDs: [session.id])
                }) {
                    Label("Delete", systemImage: "trash")
                }
            }
        } preview: {
            SessionPreviewView(session: session)
        }
#else
        .onTapGesture {
            selection = [session.id]
        }
#endif
    }

    private func isSessionSelected(_ session: LoggerSessionEntity) -> Bool {
        filters.sessions.contains(session.id)
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

private func relativeString(for date: Date, relativeTo now: Date) -> String {
    let totalMinutes = max(0, Int(now.timeIntervalSince(date) / 60))
    if totalMinutes < 1 { return "just now" }
    if totalMinutes < 60 {
        return "\(totalMinutes) min ago"
    }
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if minutes == 0 { return "\(hours) hr ago" }
    return "\(hours) hr \(minutes) min ago"
}

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

    var isSelected = false
    var sessionNumber: Int?
    var messageCount: Int?
    var isLoadingMessageCount = false

    package init(session: LoggerSessionEntity, isCompact: Bool = true, isSelected: Bool = false, sessionNumber: Int? = nil, messageCount: Int? = nil, isLoadingMessageCount: Bool = false) {
        self.session = session
        self.isCompact = isCompact
        self.isSelected = isSelected
        self.sessionNumber = sessionNumber
        self.messageCount = messageCount
        self.isLoadingMessageCount = isLoadingMessageCount
    }

    package var body: some View {
        HStack(alignment: .center) {
            if let sessionNumber {
                Text("#\(sessionNumber)")
                    .foregroundStyle(.secondary)
            }
            sessionTitle
#if os(iOS) || os(visionOS)
            if store.currentSessionID == session.id {
                Text("Current")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.12), in: Capsule())
            }
            if editMode?.wrappedValue.isEditing != true, isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
#else
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
#endif
            Spacer()
            if isLoadingMessageCount {
                Text("888")
                    .foregroundStyle(.secondary)
                    .redacted(reason: .placeholder)
            } else if let messageCount {
                Text("\(messageCount)")
                    .foregroundStyle(.secondary)
            }
        }
        .tag(session.id)
#if os(iOS) || os(visionOS)
        .listRowBackground((editMode?.wrappedValue.isEditing ?? false) ? Color.clear : nil)
#endif
    }

    private var titleWeight: Font.Weight {
        store.currentSessionID == session.id ? .bold : .regular
    }

    @ViewBuilder
    private var sessionTitle: some View {
        if Calendar.current.isDateInToday(session.createdAt) {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(relativeString(for: session.createdAt, relativeTo: context.date))
                    .fontWeight(titleWeight)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                    .layoutPriority(1)
            }
        } else {
            Text(session.formattedDate(isCompact: isCompact))
                .fontWeight(titleWeight)
                .lineLimit(1)
                .foregroundColor(.primary)
                .layoutPriority(1)
        }
    }
}

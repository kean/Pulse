// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData

@available(iOS 15, macOS 13, *)
struct ConsoleSessionsPickerView: View {
    @Binding var selection: Set<UUID>
    @State private var isShowingPicker = false

    @Environment(\.store) private var store: LoggerStore

#if os(watchOS) || os(tvOS)
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \LoggerSessionEntity.createdAt, ascending: false)])
    private var sessions: FetchedResults<LoggerSessionEntity>
#endif

    var body: some View {
#if os(iOS)
        NavigationLink(destination: SessionPickerView(selection: $selection)) {
            InfoRow(title: "Sessions", details: selectedSessionTitle)
        }
#elseif os(macOS)
        HStack {
            Text(selectedSessionTitle)
                .lineLimit(1)
                .foregroundColor(.secondary)
            Spacer()
            Button("Select...") { isShowingPicker = true }
        }
        .popover(isPresented: $isShowingPicker, arrowEdge: .trailing) {
            SessionPickerView(selection: $selection)
                .frame(width: 260, height: 370)

        }
#else
        ConsoleSearchListSelectionView(
            title: "Sessions",
            items: sessions,
            id: \.id,
            selection: $selection,
            description: \.formattedDate,
            label: { ConsoleSessionCell(session: $0, isCompact: false) },
            limit: 3
        )
#endif
    }

    private var selectedSessionTitle: String {
        if selection.isEmpty {
            return "None"
        } else if selection == [store.session.id] {
            return "Current"
        } else if selection.count == 1, let session = session(withID: selection.first!) {
            return session.formattedDate
        } else {
#if os(macOS)
            return "\(selection.count) Sessions Selected"
#else
            return "\(selection.count)"
#endif
        }
    }

    private func session(withID id: UUID) -> LoggerSessionEntity? {
        let request = NSFetchRequest<LoggerSessionEntity>(entityName: String(describing: LoggerSessionEntity.self))
        request.predicate = NSPredicate(format: "id == %@", id as NSUUID)
        request.fetchLimit = 1
        return try? store.viewContext.fetch(request).first
    }
}

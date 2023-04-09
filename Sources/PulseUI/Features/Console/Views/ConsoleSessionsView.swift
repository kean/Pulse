// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import Foundation
import SwiftUI
import Pulse
import CoreData
import Combine

#warning("fix hang when removing session selection")

struct ConsoleSessionsView: View {
    @FetchRequest(sortDescriptors: [SortDescriptor(\.createdAt, order: .reverse)])
    private var sessions: FetchedResults<LoggerSessionEntity>

    @Environment(\.store) private var store
    @State private var selection: Set<LoggerSessionEntity> = []
    @State private var limit = 20

    @EnvironmentObject private var consoleViewModel: ConsoleViewModel

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

    private var content: some View {
        List(selection: $selection) {
            if sessions.count > 20 {
                ForEach(sessions.prefix(limit), id: \.objectID, content: makeCell)
                Button("Show Previous Sessions") {
                    limit = Int.max
                }
                .buttonStyle(.link)
                .padding(.top, 8)
            } else {
                ForEach(sessions, id: \.objectID, content: makeCell)
            }
        }
        .listStyle(.inset)
        .backport.hideListContentBackground()
        .contextMenu(forSelectionType: LoggerSessionEntity.self, menu: { selection in
            if !store.isArchive {
                Button(role: .destructive, action: {
                    store.removeSessions(withIDs: selection.map(\.id))
                }, label: { Text("Remove") })
            }
        })
        .onChange(of: selection) {
            consoleViewModel.searchCriteriaViewModel.select(sessions: $0)
        }
    }

    private func makeCell(for session: LoggerSessionEntity) -> some View {
        HStack {
            Text("\(dateFormatter.string(from: session.createdAt))")
                .lineLimit(1)
                .layoutPriority(1)
            Spacer()
            if let version = session.fullVersion {
                Text(version)
                    .lineLimit(1)
                    .frame(minWidth: 40)
                    .foregroundColor(Color(UXColor.tertiaryLabelColor))
            }
        }
        .tag(session)
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    formatter.doesRelativeDateFormatting = true
    return formatter
}()

private extension LoggerSessionEntity {
    var fullVersion: String? {
        guard let version = version else {
            return nil
        }
        if let build = build {
            return version + " (\(build))"
        }
        return version
    }
}

#if DEBUG
struct Previews_ConsoleSessionsView_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleSessionsView()
            .injectingEnvironment(ConsoleViewModel(store: .mock))
    }
}
#endif

#endif

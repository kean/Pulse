// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import Foundation
import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15.0, *)
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
#if os(macOS)
                .buttonStyle(.link)
#endif
                .padding(.top, 8)
            } else {
                ForEach(sessions, id: \.objectID, content: makeCell)
            }
        }
#if os(iOS)
        .listStyle(.plain   )
        .onAppear {
            selection = consoleViewModel.searchCriteriaViewModel.options.sessions
        }
#else
        .listStyle(.inset)
        .backport.hideListContentBackground()
        .contextMenu(forSelectionType: LoggerSessionEntity.self, menu: { selection in
            if !store.isArchive {
                Button(role: .destructive, action: {
                    store.removeSessions(withIDs: selection.map(\.id))
                }, label: { Text("Remove") })
            }
        })
#endif
        .onChange(of: selection) {
            guard consoleViewModel.searchCriteriaViewModel.options.sessions != $0 else { return }
            consoleViewModel.searchCriteriaViewModel.select(sessions: $0)
#if os(iOS)
            consoleViewModel.router.isShowingSessions = false
#endif
        }
    }

    private func makeCell(for session: LoggerSessionEntity) -> some View {
        HStack(alignment: .center) {
            Text("\(dateFormatter.string(from: session.createdAt))")
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
                    .font(.caption)
                    .foregroundColor(.secondary)
#endif
            }
#if os(iOS)
            if selection.contains(session) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
#endif
        }
        .listRowBackground(Color.clear)
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
@available(iOS 15.0, *)
struct Previews_ConsoleSessionsView_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleSessionsView()
            .injectingEnvironment(ConsoleViewModel(store: .mock))
    }
}
#endif

#endif

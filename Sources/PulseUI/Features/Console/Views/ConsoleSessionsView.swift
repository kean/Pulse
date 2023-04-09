// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import Foundation
import SwiftUI
import Pulse
import CoreData
import Combine

#warning("add app version to info? what other info can I add?")
#warning("improve item design: less spacing, etc")
#warning("fix how it works with remote logging")
#warning("highlight current session")
#warning("add filters")
#warning("fix hang when removing session selection")
#warning("add a way to remove session")

struct ConsoleSessionsView: View {
    @FetchRequest(sortDescriptors: [SortDescriptor(\.createdAt, order: .reverse)])
    private var sessions: FetchedResults<LoggerSessionEntity>

    @Environment(\.store) private var store
    @State private var selection: Set<LoggerSessionEntity> = []

    @EnvironmentObject private var consoleViewModel: ConsoleViewModel

    #warning("temp")
    var body: some View {
        if let version = Version(store.version), version < Version(3, 6, 0) {
            PlaceholderView(imageName: "questionmark.app", title: "Unsupported", subtitle: "This feature requires a store created by Pulse version 3.6.0 or higher").padding()
        } else {
            content
        }
    }

    private var content: some View {
        List(selection: $selection) {
            ForEach(sessions, id: \.objectID, content: makeCell)
        }
        .listStyle(.inset)
        .backport.hideListContentBackground()
        .onChange(of: selection) {
#warning("optimize this")
            var dates = consoleViewModel.searchCriteriaViewModel.criteria.shared.dates
            dates.startDate = nil
            dates.endDate = nil
            consoleViewModel.searchCriteriaViewModel.criteria.shared.dates = dates
            consoleViewModel.searchCriteriaViewModel.sessions = $0
        }
    }

    #warning("reimplement how session numbers are displayed")
    private func makeCell(for session: LoggerSessionEntity) -> some View {
        HStack {
//            Text("\(session.id)")
//                .foregroundColor(Color.secondary)
//                .frame(minWidth: 16, alignment: .trailing)
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

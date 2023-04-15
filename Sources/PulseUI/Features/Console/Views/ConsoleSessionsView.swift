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
#warning("is select all in the right place?")
@available(macOS 13, *)
struct ConsoleSessionsView: View {
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \LoggerSessionEntity.createdAt, ascending: false)])
    private var sessions: FetchedResults<LoggerSessionEntity>

    @State private var filterTerm = ""
    @State private var selection: Set<UUID> = []
    @State private var limit = 16
    @State private var isSharing = false

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
                    Button("Done") {
                        consoleViewModel.searchCriteriaViewModel.select(sessions: selection)
                        consoleViewModel.router.isShowingSessions = false
                    }
                }
                ToolbarItem(placement: .bottomBar) { bottomBar }
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
                ForEach(getFilteredSessions(), id: \.objectID, content: makeCell)
            } else {
#if os(iOS)
                buttonToggleSelectAll
#endif
                if sessions.count > limit {
                    ForEach(sessions.prefix(limit), id: \.objectID, content: makeCell)
                    buttonShowPreviousSessions
                } else {
                    ForEach(sessions, id: \.objectID, content: makeCell)
                }
            }
        }
#if os(iOS)
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
        .onAppear {
            selection = consoleViewModel.searchCriteriaViewModel.criteria.shared.sessions
        }
        .backport.searchable(text: $filterTerm)
#else
        .listStyle(.inset)
        .backport.hideListContentBackground()
        .contextMenu(forSelectionType: UUID.self, menu: contextMenu)
        .onChange(of: selection) {
            guard consoleViewModel.searchCriteriaViewModel.criteria.shared.sessions != $0 else { return }
            consoleViewModel.searchCriteriaViewModel.select(sessions: $0)
        }
#endif
    }

#if os(iOS)
    private var buttonToggleSelectAll: some View {
        Button(action: {
            if sessions.count == selection.count {
                selection = []
            } else {
                selection = Set(sessions.map(\.id))
            }
        }) {
            HStack {
                Text(sessions.count == selection.count ? "Deselect All" : "Select All")
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(.blue)
    }

    private var bottomBar: some View {
        HStack {
            Button.destructive(action: {
                store.removeSessions(withIDs: selection)
            }, label: { Image(systemName: "trash").foregroundColor(.red) })
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
#endif

    private func makeCell(for session: LoggerSessionEntity) -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text(session.formattedDate)
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
        }
        .listRowBackground(Color.clear)
        .tag(session.id)
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

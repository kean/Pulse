// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

struct ConsoleListContentView: View {
    @ObservedObject var viewModel: ConsoleListViewModel

#if os(iOS)

    var body: some View {
        if #available(iOS 15, tvOS 15, *) {
            if !viewModel.pins.isEmpty, case .store = viewModel.source {
                pinsView
            }
        }
        if #available(iOS 15, *), let sections = viewModel.sections, !sections.isEmpty {
            makeGroupedView(sections)
        } else {
            plainView
        }
    }

    @available(iOS 15.0, *)
    private func makeGroupedView(_ sections: [NSFetchedResultsSectionInfo]) -> some View {
        ForEach(sections, id: \.name) { section in
            let objects = (section.objects as? [NSManagedObject]) ?? []
            let prefix = objects.prefix(3)
            let sectionName = viewModel.makeName(for: section)
            PlainListExpandableSectionHeader(title: sectionName, count: section.numberOfObjects, destination: { EmptyView() }, isSeeAllHidden: true)
            ForEach(prefix, id: \.objectID) { entity in
                ConsoleEntityCell.make(for: entity)
            }
            if prefix.count < objects.count {
                NavigationLink(destination: makeDestination(for: sectionName, objects: objects)) {
                    PlainListSeeAllView(count: objects.count)
                }
            }
        }
    }

    private func makeDestination(for title: String, objects: [NSManagedObject]) -> some View {
        LazyConsoleView(title: title, entities: objects, store: viewModel.store, mode: viewModel.mode)
    }
#else
    var body: some View {
        plainView
    }
#endif

    @ViewBuilder
    private var plainView: some View {
        if viewModel.visibleEntities.isEmpty {
            Text("No Recorded Logs")
                .font(.subheadline)
                .foregroundColor(.secondary)
        } else {
            ForEach(viewModel.visibleEntities, id: \.objectID) { entity in
                ConsoleEntityCell.make(for: entity)
                    .onAppear { viewModel.onAppearCell(with: entity.objectID) }
                    .onDisappear { viewModel.onDisappearCell(with: entity.objectID) }
            }
        }
        footerView
    }

    @available(iOS 15, tvOS 15, *)
    @ViewBuilder
    private var pinsView: some View {
        let prefix = Array(viewModel.pins.prefix(3))
        PlainListExpandableSectionHeader(title: "Pins", count: viewModel.pins.count, destination: {
            ConsolePlainList(viewModel.pins)
                .inlineNavigationTitle("Pins")
#if os(iOS)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: viewModel.buttonRemovePinsTapped) {
                            Image(systemName: "trash")
                        }
                    }
                }
#endif
        }, isSeeAllHidden: prefix.count == viewModel.pins.count)
        ForEach(prefix.map(PinCellViewModel.init)) { viewModel in
            ConsoleEntityCell.make(for: viewModel.object)
        }
        Button(action: viewModel.buttonRemovePinsTapped) {
            Text("Remove Pins")
                .font(.subheadline)
                .foregroundColor(Color.blue)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
#if os(iOS)
        .listRowBackground(Color.separator.opacity(0.2))
        .listRowSeparator(.hidden)
        .listRowSeparator(.hidden, edges: .bottom)
#endif
        if !viewModel.visibleEntities.isEmpty {
            PlainListGroupSeparator()
        }
    }

    @ViewBuilder
    private var footerView: some View {
        if #available(iOS 15, *), viewModel.isShowPreviousSessionButtonShown, case .store = viewModel.source {
            Button(action: viewModel.buttonShowPreviousSessionTapped) {
                Text("Show Previous Sessions")
                    .font(.subheadline)
                    .foregroundColor(Color.blue)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
#if os(iOS)
            .listRowSeparator(.hidden, edges: .bottom)
#endif
        }
    }
}

struct ConsolePlainList: View {
    let entities: [NSManagedObject]

    init(_ entities: [NSManagedObject]) {
        self.entities = entities
    }

    public var body: some View {
        List {
            ForEach(entities, id: \.objectID, content: ConsoleEntityCell.init)
        }.listStyle(.plain)
    }
}

private struct PinCellViewModel: Hashable, Identifiable {
    let object: NSManagedObject
    var id: PinCellId

    init(_ object: NSManagedObject) {
        self.object = object
        self.id = PinCellId(id: object.objectID)
    }
}

// Make sure the cells 
private struct PinCellId: Hashable {
    let id: NSManagedObjectID
}

#if os(iOS)
private struct LazyConsoleView: View {
    let title: String
    let entities: [NSManagedObject]
    let store: LoggerStore
    let mode: ConsoleMode

    var body: some View {
        ConsoleView(viewModel: .init(store: store, source: .entities(title: title, entities: entities), mode: mode))
            .navigationBarTitleDisplayMode(.inline)
    }
}
#endif

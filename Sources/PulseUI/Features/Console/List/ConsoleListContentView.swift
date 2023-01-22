// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

struct ConsoleListContentView: View {
    @ObservedObject var viewModel: ConsoleListViewModel
    @State private var expandedSections: Set<String> = []
    @State private var isPinnedSectionExpanded = false

#if os(iOS)

    var body: some View {
        if #available(iOS 15, *), let sections = viewModel.sections, !sections.isEmpty {
            makeGroupedView(sections)
        } else {
            plainView
        }
    }

    @available(iOS 15.0, *)
    private func makeGroupedView(_ sections: [NSFetchedResultsSectionInfo]) -> some View {
        ForEach(sections, id: \.name) { section in
            PlainListSectionHeader(title: "\(makeName(for: section)) (\(section.numberOfObjects))")
            let objects = (section.objects as? [NSManagedObject]) ?? []
            let prefix = expandedSections.contains(section.name) ? objects : Array(objects.prefix(4))
            ForEach(prefix, id: \.objectID) { entity in
                ConsoleEntityCell(entity: entity)
            }
            if prefix.count < objects.count {
                Button(action: { expandedSections.insert(section.name) }) {
                    Text("Show More") + Text(" (\(objects.count - prefix.count))").foregroundColor(.secondary)
                }
            }
        }
    }

    private func makeName(for section: NSFetchedResultsSectionInfo) -> String {
        if viewModel.mode != .tasks  {
            if viewModel.options.messageGroupBy == .level {
                let rawValue = Int16(Int(section.name) ?? 0)
                return (LoggerStore.Level(rawValue: rawValue) ?? .debug).name.capitalized
            }
        } else {
            if viewModel.options.taskGroupBy == .taskType {
                let rawValue = Int16(Int(section.name) ?? 0)
                return NetworkLogger.TaskType(rawValue: rawValue)?.urlSessionTaskClassName ?? section.name
            }
            if viewModel.options.taskGroupBy == .statusCode {
                let rawValue = Int32(section.name) ?? 0
                return StatusCodeFormatter.string(for: rawValue)
            }
        }
        let name = section.name
        return name.isEmpty ? "–" : name
    }

#else
    var body: some View {
        plainView
    }
#endif

    @ViewBuilder
    private var plainView: some View {
        if #available(iOS 15, tvOS 15, *) {
            if !viewModel.pins.isEmpty {
                pinsView
            }
        }
        ForEach(viewModel.visibleEntities, id: \.objectID) { entity in
            ConsoleEntityCell(entity: entity)
                .onAppear { viewModel.onAppearCell(with: entity.objectID) }
                .onDisappear { viewModel.onDisappearCell(with: entity.objectID) }
        }
        footerView
    }

    @available(iOS 15, tvOS 15, *)
    @ViewBuilder
    private var pinsView: some View {
        PlainListExpandableSectionHeader(title: "Pins", count: viewModel.pins.count, destination: {
            ConsolePlainList(viewModel.pins)
                .inlineNavigationTitle("Pins")
        })
        let prefix = isPinnedSectionExpanded ? viewModel.pins : Array(viewModel.pins.prefix(4))
        ForEach(prefix, id: \.objectID) { entity in
            ConsoleEntityCell(entity: entity)
        }
        if prefix.count < viewModel.pins.count {
            Button(action: { isPinnedSectionExpanded = true }) {
                Text("Show More") + Text(" (\(viewModel.pins.count - prefix.count))").foregroundColor(.secondary)
            }
        }
        if !viewModel.visibleEntities.isEmpty {
            PlainListGroupSeparator()
        }
    }

    @ViewBuilder
    private var footerView: some View {
        if #available(iOS 15, *), viewModel.isShowPreviousSessionButtonShown {
            Button(action: viewModel.buttonShowPreviousSessionTapped) {
                Text("Show Previous Sessions")
                    .font(.subheadline)
                    .foregroundColor(Color.blue)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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

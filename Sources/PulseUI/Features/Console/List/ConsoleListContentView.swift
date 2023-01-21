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
            PlainListClearSectionHeader(title: "\(makeName(for: section)) (\(section.numberOfObjects))")
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
        if !viewModel.isOnlyNetwork {
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

    private var plainView: some View {
        ForEach(viewModel.visibleEntities, id: \.objectID) { entity in
            ConsoleEntityCell(entity: entity)
                .onAppear { viewModel.onAppearCell(with: entity.objectID) }
                .onDisappear { viewModel.onDisappearCell(with: entity.objectID) }
        }
    }
}

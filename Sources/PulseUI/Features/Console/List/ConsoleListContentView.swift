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
        if #available(iOS 15, *), let sections = viewModel.sections, !sections.isEmpty {
            makeGroupedView(sections)
        } else {
            plainView
        }
    }

    @available(iOS 15.0, *)
    private func makeGroupedView(_ sections: [NSFetchedResultsSectionInfo]) -> some View {
        ForEach(sections, id: \.name) { section in
            PlainListClearSectionHeader(title: "\(makeName(for: section).capitalized) (\(section.numberOfObjects))")
            ForEach((section.objects as? [NSManagedObject]) ?? [], id: \.objectID) { entity in
                ConsoleEntityCell(entity: entity)
            }
        }
    }

    private func makeName(for section: NSFetchedResultsSectionInfo) -> String {
        if !viewModel.isOnlyNetwork, viewModel.options.messageGroupBy == .level {
            let rawValue = Int16(Int(section.name) ?? 0)
            return (LoggerStore.Level(rawValue: rawValue) ?? .debug).name
        }
        return section.name
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

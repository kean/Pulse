// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import CoreData
import Pulse
import Combine
import SwiftUI

@available(iOS 15.0, *)
struct ConsoleListGroupedSectionView: View {
    let section: NSFetchedResultsSectionInfo
    @ObservedObject var viewModel: ConsoleListViewModel
    @EnvironmentObject private var consoleViewModel: ConsoleViewModel

    var body: some View {
        let objects = (section.objects as? [NSManagedObject]) ?? []
        let prefix = objects.prefix(3)
        let title = viewModel.name(for: section)

        PlainListExpandableSectionHeader(title: title, count: section.numberOfObjects, destination: { EmptyView() }, isSeeAllHidden: true)

        ForEach(prefix, id: \.objectID, content: ConsoleEntityCell.init)

        if prefix.count < objects.count {
#if os(iOS)
            NavigationLink(destination: LazyConsoleView(title: title, entities: objects, source: viewModel)) {
                PlainListSeeAllView(count: objects.count)
            }
#else
            Button(action: { consoleViewModel.focus(on: objects) }) {
                PlainListSeeAllView(count: objects.count)
            }.buttonStyle(.plain)
#endif
        }
    }
}

#endif

#if os(iOS)

private struct LazyConsoleView: View {
    let title: String
    let entities: [NSManagedObject]
    let source: ConsoleListViewModel

    var body: some View {
        ConsoleView(viewModel: makeViewModel())
            .navigationBarTitleDisplayMode(.inline)
    }

    private func makeViewModel() -> ConsoleViewModel {
        let viewModel = ConsoleViewModel(
            store: source.store,
            context: .init(title: title, focus: NSPredicate(format: "self IN %@", entities)),
            mode: source.mode
        )
        viewModel.listViewModel.options.order = source.options.order
        viewModel.listViewModel.options.messageSortBy = source.options.messageSortBy
        viewModel.listViewModel.options.taskSortBy = source.options.taskSortBy
        return viewModel
    }
}

#endif
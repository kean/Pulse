// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import CoreData
import Pulse
import Combine
import SwiftUI

@available(iOS 15, macOS 13, *)
struct ConsoleListGroupedSectionView: View {
    let section: NSFetchedResultsSectionInfo
    @ObservedObject var viewModel: ConsoleListViewModel
    @EnvironmentObject private var environment: ConsoleEnvironment

    var body: some View {
        let objects = (section.objects as? [NSManagedObject]) ?? []
        let prefix = objects.prefix(3)
        let title = viewModel.name(for: section)

        PlainListExpandableSectionHeader(title: title, count: section.numberOfObjects, destination: { EmptyView() }, isSeeAllHidden: true)

        ForEach(prefix, id: \.objectID, content: ConsoleEntityCell.init)

        if prefix.count < objects.count {
#if os(iOS)
            NavigationLink(destination: ConsoleStaticList(entities: objects).inlineNavigationTitle(title)) {
                PlainListSeeAllView(count: objects.count)
            }
#else
            Button(action: { viewModel.focus(on: objects) }) {
                PlainListSeeAllView(count: objects.count)
            }.buttonStyle(.plain)
#endif
        }
    }
}

#endif

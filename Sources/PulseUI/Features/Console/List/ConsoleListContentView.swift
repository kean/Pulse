// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(tvOS) || os(visionOS) || os(watchOS)

import CoreData
import Pulse
import Combine
import SwiftUI

@available(iOS 15, visionOS 1.0, *)
struct ConsoleListContentView: View {
    @EnvironmentObject var viewModel: ConsoleListViewModel

    var body: some View {
        plainView
    }

    @ViewBuilder
    private var plainView: some View {
        if viewModel.entities.isEmpty {
            Text("Empty")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 16))
        } else {
            ForEach(viewModel.visibleEntities, id: \.objectID) { entity in
                let objectID = entity.objectID
                ConsoleEntityCell(entity: entity)
                    .id(objectID)
#if os(iOS) || os(visionOS)
                    .onAppear { viewModel.onAppearCell(with: objectID) }
                    .onDisappear { viewModel.onDisappearCell(with: objectID) }
#endif
#if os(iOS)
                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 16))
#endif
            }
        }
        footerView
            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 16))
    }

    @ViewBuilder
    private var footerView: some View {
        if let session = viewModel.previousSession {
            Button(action: { viewModel.buttonShowPreviousSessionTapped(for: session) }) {
                Text("Show Previous Session")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                Spacer()
                Text(session.formattedDate(isCompact: false))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
#if os(iOS) || os(visionOS)
            .listRowSeparator(.hidden, edges: .bottom)
#endif
        }
    }
}

#if os(iOS) || os(visionOS)
@available(iOS 15, visionOS 1.0, *)
struct ConsoleStaticList: View {
    let entities: [NSManagedObject]

    var body: some View {
        List {
            ForEach(entities, id: \.objectID, content: Components.makeConsoleEntityCell)
        }
        .listStyle(.plain)
#if os(iOS) || os(visionOS)
        .environment(\.defaultMinListRowHeight, 8)
#endif
    }
}
#endif

#endif

// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

@available(iOS 15, macOS 13, visionOS 1.0, *)
struct ConsoleListContentView: View {
    @EnvironmentObject var viewModel: ConsoleListViewModel

    var body: some View {
#if os(iOS) || os(visionOS)
        if !viewModel.pins.isEmpty, !viewModel.isShowingFocusedEntities {
            ConsoleListPinsSectionView(viewModel: viewModel)
            if !viewModel.entities.isEmpty {
                PlainListGroupSeparator()
            }
        }
#endif
        plainView
    }

    @ViewBuilder
    private var plainView: some View {
        if viewModel.entities.isEmpty {
            Text("Empty")
                .font(.subheadline)
                .foregroundColor(.secondary)
        } else {
            ForEach(viewModel.visibleEntities, id: \.objectID) { entity in
                let objectID = entity.objectID
                ConsoleEntityCell(entity: entity)
                    .id(objectID)
#if os(iOS) || os(visionOS) || os(macOS)
                    .onAppear { viewModel.onAppearCell(with: objectID) }
                    .onDisappear { viewModel.onDisappearCell(with: objectID) }
#endif
            }
        }
        footerView
    }

    @ViewBuilder
    private var footerView: some View {
        if let session = viewModel.previousSession, !viewModel.isShowingFocusedEntities {
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

#if os(iOS) || os(macOS) || os(visionOS)
@available(iOS 15, macOS 13, visionOS 1.0, *)
struct ConsoleStaticList: View {
    let entities: [NSManagedObject]

    var body: some View {
        List {
            ForEach(entities, id: \.objectID, content: ConsoleEntityCell.init)
        }
        .listStyle(.plain)
#if os(iOS) || os(visionOS)
        .environment(\.defaultMinListRowHeight, 8)
#endif
    }
}
#endif

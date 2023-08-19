// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

@available(iOS 15, macOS 13, *)
struct ConsoleListContentView: View {
    @EnvironmentObject var viewModel: ConsoleListViewModel

#if os(macOS)
    let proxy: ScrollViewProxy

    @SceneStorage("com-github-kean-pulse-is-now-enabled") private var isNowEnabled = true
#endif

    var body: some View {
#if os(iOS)
        if !viewModel.pins.isEmpty, !viewModel.isShowingFocusedEntities {
            ConsoleListPinsSectionView(viewModel: viewModel)
            if !viewModel.entities.isEmpty {
                PlainListGroupSeparator()
            }
        }
#endif

#if os(iOS) || os(macOS)
        if let sections = viewModel.sections, !sections.isEmpty {
            ForEach(sections, id: \.name) {
                ConsoleListGroupedSectionView(section: $0, viewModel: viewModel)
            }
        } else {
            plainView
#if os(macOS)
                .apply(registerNowMode)
#endif
        }
#else
        plainView
#endif
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
#if os(iOS)
                    .onAppear { viewModel.onAppearCell(with: objectID) }
                    .onDisappear { viewModel.onDisappearCell(with: objectID) }
#endif
            }
        }
#if os(macOS)
        bottomAnchorView
#else
        footerView
#endif
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
#if os(iOS)
            .listRowSeparator(.hidden, edges: .bottom)
#endif
        }
    }

#if os(macOS)
    private func registerNowMode<T: View>(for list: T) -> some View {
        list.onChange(of: viewModel.entities) { entities in
            guard isNowEnabled else { return }

            withAnimation {
                proxy.scrollTo(BottomViewID(), anchor: .top)
            }
            // This is a workaround that fixes a scrolling issue when more
            // than one row is added at the time.
            DispatchQueue.main.async {
                proxy.scrollTo(BottomViewID(), anchor: .top)
            }
        }
        .onChange(of: isNowEnabled) {
            guard $0 else { return }
            proxy.scrollTo(BottomViewID(), anchor: .top)
        }
    }

    // This view is used to keep scroll to the bottom and keep track of the
    // scroll position (near bottom or not).
    private var bottomAnchorView: some View {
        HStack { EmptyView() }
            .frame(height: 1)
            .id(BottomViewID())
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .onAppear {
                nowModeChange?.cancel()
            }
            .onDisappear {
                // The scrolling with ScrollViewProxy is unreliable, and this cell
                // occasionally disappears.
                delayNowModeChange {
                    guard viewModel.isViewVisible else { return }
                    isNowEnabled = false
                }
            }
    }
#endif
}

#if os(macOS)
private var nowModeChange: DispatchWorkItem?

private func delayNowModeChange(_ closure: @escaping () -> Void) {
    nowModeChange?.cancel()
    let item = DispatchWorkItem(block: closure)
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(64), execute: item)
    nowModeChange = item
}

struct BottomViewID: Hashable, Identifiable {
    var id: BottomViewID { self}
}
#endif

#if os(iOS) || os(macOS)
@available(iOS 15, macOS 13, *)
struct ConsoleStaticList: View {
    let entities: [NSManagedObject]

    var body: some View {
        List {
            ForEach(entities, id: \.objectID, content: ConsoleEntityCell.init)
        }
        .listStyle(.plain)
#if os(iOS)
        .environment(\.defaultMinListRowHeight, 8)
#endif
    }
}
#endif

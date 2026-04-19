// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(tvOS) || os(macOS) || os(visionOS) || os(watchOS)

import CoreData
import Pulse
import Combine
import SwiftUI

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct ConsoleListContentView: View {
    var hidesPreviousSessionButton: Bool = false

    @EnvironmentObject var viewModel: ConsoleListViewModel

    var body: some View {
#if os(iOS) || os(visionOS)
        if let sections = viewModel.sections, !sections.isEmpty {
            ForEach(sections, id: \.name) { section in
                let isCollapsed = viewModel.collapsedSections.contains(section.name)
                Section {
                    if !isCollapsed {
                        ForEach((section.objects as? [NSManagedObject]) ?? [], id: \.objectID) { entity in
                            ConsoleEntityCell(entity: entity)
                                .id(entity.objectID)
                                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 16))
                        }
                    }
                } header: {
                    Button(action: { withAnimation { viewModel.toggleSection(section.name) } }) {
                        HStack {
                            Text(viewModel.name(for: section))
                            Text("\(section.numberOfObjects)")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            plainView
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
#if !os(watchOS)
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 16))
#endif
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
    }

    @ViewBuilder
    private var footerView: some View {
#if os(iOS) && os(macOS) || os(visionOS)
        if !hidesPreviousSessionButton, let session = viewModel.previousSession {
            Button(action: {
                withAnimation {
                    viewModel.buttonShowPreviousSessionTapped(for: session)
                }
            }) {
                HStack(spacing: 10) {
                    Spacer()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Previous Session")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                    Spacer()
                }
            }
            .frame(height: 24)
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            .listRowSeparator(.hidden, edges: .bottom)
        }
#endif
    }
}

#if os(iOS) || os(visionOS)
@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
package struct ConsoleStaticList: View {
    package let entities: [NSManagedObject]

    package init(entities: [NSManagedObject]) {
        self.entities = entities
    }

    package var body: some View {
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

#endif

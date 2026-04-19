// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS)

import SwiftUI
import Pulse

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct ConsoleRecentFiltersListView: View {
    @ObservedObject var store: ConsoleRecentFiltersStore
    let mode: ConsoleMode
    var onSelect: (ConsoleRecentFilter) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Recent Filters")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        ButtonClose()
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear All", role: .destructive) {
                            store.clear()
                            dismiss()
                        }
                        .disabled(store.recents.isEmpty)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.recents.isEmpty {
            ContentUnavailableView(
                "No Recent Filters",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("Filters you apply in the console will appear here.")
            )
        } else {
            List {
                ForEach(store.recents) { entry in
                    Button(action: { apply(entry) }) {
                        row(for: entry)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            store.remove(entry)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            store.remove(entry)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private func row(for entry: ConsoleRecentFilter) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.filters.summary(for: mode) ?? "Filters")
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle(for: entry))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }

    private func subtitle(for entry: ConsoleRecentFilter) -> String {
        let count = entry.filters.activeFilterCount(for: mode)
        let filters = count == 1 ? "1 filter" : "\(count) filters"
        let date = entry.lastUsedDate.formatted(.relative(presentation: .named))
        return "\(filters) · \(date)"
    }

    private func apply(_ entry: ConsoleRecentFilter) {
        onSelect(entry)
        dismiss()
    }
}

#endif

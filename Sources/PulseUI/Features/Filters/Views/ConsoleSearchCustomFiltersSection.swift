// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct ConsoleSearchCustomFiltersSection: View {
    @Binding var filters: [ConsoleCustomFilter]
    var fieldGroups: [ConsoleCustomFilter.FieldGroup]
    var defaultFilter: ConsoleCustomFilter
    var emptyMessage: String?

    @State private var editingFilterID: UUID?
    @State private var isAddingFilter = false

    var body: some View {
        ForEach(filters) { filter in
            if !filter.value.isEmpty {
                HStack {
                    Button { editingFilterID = filter.id } label: {
                        ConsoleCustomFilterSummaryView(
                            field: filter.fieldTitle, match: filter.matchTitle,
                            value: filter.value, isEnabled: filter.isEnabled
                        )
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button { removeFilter(id: filter.id) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .imageScale(.medium)
                    }
                    .buttonStyle(.plain)
                }
                #if os(watchOS)
                .contextMenu {
                    Button { editingFilterID = filter.id } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button { toggleFilter(id: filter.id) } label: {
                        Label(filter.isEnabled ? "Disable" : "Enable",
                              systemImage: filter.isEnabled ? "eye.slash" : "eye")
                    }
                    Button { duplicateFilter(filter) } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    Button(role: .destructive) { removeFilter(id: filter.id) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                #else
                .contextMenu {
                    Button { editingFilterID = filter.id } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button { toggleFilter(id: filter.id) } label: {
                        Label(filter.isEnabled ? "Disable" : "Enable",
                              systemImage: filter.isEnabled ? "eye.slash" : "eye")
                    }
                    Button { duplicateFilter(filter) } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    Button(role: .destructive) { removeFilter(id: filter.id) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } preview: {
                    ConsoleCustomFilterPreview(field: filter.fieldTitle, match: filter.matchTitle, value: filter.value)
                }
                #endif
                #if !os(tvOS)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) { removeFilter(id: filter.id) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button { toggleFilter(id: filter.id) } label: {
                        Label(filter.isEnabled ? "Disable" : "Enable",
                              systemImage: filter.isEnabled ? "eye.slash" : "eye")
                    }
                    .tint(filter.isEnabled ? .orange : .green)
                }
                #endif
            }
        }
        addButton
            .sheet(isPresented: $isAddingFilter) {
                ConsoleCustomFilterEditSheet(filter: defaultFilter, fieldGroups: fieldGroups) {
                    addFilter($0)
                }
            }
            .sheet(isPresented: isEditingBinding) {
                if let index = editingFilterIndex {
                    ConsoleCustomFilterEditSheet(filter: filters[index], fieldGroups: fieldGroups, onSave: { filters[index] = $0 }, onDelete: { filters.remove(at: index) })
                }
            }
    }

    private var addButton: some View {
        Button("Add Filter") {
            isAddingFilter = true
        }
    }

    private var isEditingBinding: Binding<Bool> {
        Binding(get: { editingFilterID != nil }, set: { if !$0 { editingFilterID = nil } })
    }

    private var editingFilterIndex: Int? {
        editingFilterID.flatMap { id in filters.firstIndex(where: { $0.id == id }) }
    }

    private func addFilter(_ filter: ConsoleCustomFilter) {
        if let emptyIndex = filters.firstIndex(where: { $0.value.isEmpty }) {
            filters[emptyIndex] = filter
        } else {
            filters.append(filter)
        }
    }

    private func removeFilter(id: UUID) {
        if let index = filters.firstIndex(where: { $0.id == id }) {
            if filters.count > 1 {
                filters.remove(at: index)
            } else {
                filters[index] = defaultFilter
            }
        }
    }

    private func toggleFilter(id: UUID) {
        if let index = filters.firstIndex(where: { $0.id == id }) {
            filters[index].isEnabled.toggle()
        }
    }

    private func duplicateFilter(_ filter: ConsoleCustomFilter) {
        filters.append(filter.duplicated())
    }
}

struct ConsoleFilterLogicalOperatorPicker: View {
    @Binding var selection: ConsoleFilterLogicalOperator
    let activeFilterCount: Int

    var body: some View {
        if activeFilterCount >= 2 {
            Picker("", selection: $selection) {
                Text("AND").tag(ConsoleFilterLogicalOperator.and)
                Text("OR").tag(ConsoleFilterLogicalOperator.or)
            }
            #if !os(watchOS)
            .pickerStyle(.segmented)
            #endif
            .fixedSize()
            .frame(height: 20)
        }
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct ConsoleCustomFilterSummaryView: View {
    let field: String
    let match: String
    let value: String
    var isEnabled: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            Text(field)
                .foregroundStyle(.secondary)
            Text(match.lowercased())
                .foregroundStyle(.secondary)
            Text("\u{201C}")
                .foregroundStyle(.secondary)
            + Text(value)
                .foregroundStyle(.primary)
            + Text("\u{201D}")
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct ConsoleCustomFilterPreview: View {
    let field: String
    let match: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row("Field", detail: field)
            row("Match", detail: match)
            row("Value", detail: value)
        }
        .padding()
        .frame(width: 260, alignment: .leading)
    }

    private func row(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(detail)
        }
    }
}

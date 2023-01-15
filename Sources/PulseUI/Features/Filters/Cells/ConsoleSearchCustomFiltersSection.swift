// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS) || os(macOS)

@available(iOS 15, *)
struct ConsoleSearchCustomNetworkFiltersSection: View {
    @Binding var selection: ConsoleSearchCriteria.CustomNetworkFilters

    var body: some View {
        ForEach($selection.filters) { filter in
            ConsoleCustomNetworkFilterView(filter: filter, onRemove: selection.filters.count > 1  ? { remove(filter.wrappedValue) } : nil)
        }
        if !(selection == .init()) {
            Button(action: { selection.filters.append(.default) }) {
                Text("Add Filter")
            }
        }
    }

    private func remove(_ filter: ConsoleCustomNetworkFilter) {
        if let index = selection.filters.firstIndex(where: { $0.id == filter.id }) {
            selection.filters.remove(at: index)
        }
    }
}

@available(iOS 15, *)
struct ConsoleSearchCustomMessageFiltersSection: View {
    @Binding var selection: ConsoleSearchCriteria.CustomMessageFilters

    var body: some View {
        ForEach($selection.filters) { filter in
            ConsoleCustomMessageFilterView(filter: filter, onRemove: selection.filters.count > 1  ? { remove(filter.wrappedValue) } : nil)
        }
        if !(selection == .init()) {
            Button(action: { selection.filters.append(.default) }) {
                Text("Add Filter")
            }
        }
    }

    private func remove(_ filter: ConsoleCustomMessageFilter) {
        if let index = selection.filters.firstIndex(where: { $0.id == filter.id }) {
            selection.filters.remove(at: index)
        }
    }
}

#endif

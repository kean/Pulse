// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if !os(macOS)

import SwiftUI
import Pulse

@available(iOS 16, visionOS 1, *)
package struct ConsoleSearchListSelectionView<Data: RandomAccessCollection, ID: Hashable, Label: View>: View {
    package let title: String
    package let items: Data
    package let id: KeyPath<Data.Element, ID>
    @Binding package var selection: Set<ID>
    package let description: (Data.Element) -> String
    @ViewBuilder package let label: (Data.Element) -> Label

#if os(iOS) || os(visionOS)
    package var limit = 6
#else
    package var limit = 3
#endif

    package init(
        title: String,
        items: Data,
        id: KeyPath<Data.Element, ID>,
        selection: Binding<Set<ID>>,
        description: @escaping (Data.Element) -> String,
        @ViewBuilder label: @escaping (Data.Element) -> Label,
        limit: Int? = nil
    ) {
        self.title = title
        self.items = items
        self.id = id
        self._selection = selection
        self.description = description
        self.label = label
        if let limit {
            self.limit = limit
        }
    }

    @State private var searchText = ""

    @State private var isExpandedListPresented = false
    @State private var isSearching = false

    package var body: some View {
        if items.isEmpty {
            emptyView
        } else {
            ForEach(items.prefix(limit), id: id, content: makeRow)
                .sheet(isPresented: $isExpandedListPresented) {
                    NavigationView {
                        expandedListBody
                    }
                }
            if items.count > limit {
                let viewAllView = HStack {
                    Text("View All").foregroundColor(.accentColor)
                    Spacer()
                    Text("\(items.count) ").foregroundColor(.secondary)
                }
#if os(tvOS)
                Button(action: { isExpandedListPresented = true }) { viewAllView }
#else
                NavigationLink(destination: expandedListBody) { viewAllView }
#endif
            }
        }
    }

    @ViewBuilder
    private var expandedListBody: some View {
        Form {
            buttonToggleAll
            ForEach(filteredItems, id: id, content: makeRow)
        }
        .inlineNavigationTitle(title)
#if os(tvOS)
        .frame(width: 800)
#endif
#if os(iOS) || os(visionOS)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .disableAutocorrection(true)
#else
        .searchable(text: $searchText)
        .disableAutocorrection(true)
#endif
    }

    // MARK: - Shared

    private var emptyView: some View {
        Text("Empty")
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundColor(.secondary)
    }

    private func makeRow(for item: Data.Element) -> some View {
        Checkbox(isOn: Binding(get: {
            selection.contains(item[keyPath: id])
        }, set: { isOn in
            if isOn {
                selection.insert(item[keyPath: id])
            } else {
                selection.remove(item[keyPath: id])
            }
        }), label: { label(item).lineLimit(1) })
    }

    private var filteredItems: [Data.Element] {
        searchText.isEmpty ? Array(items) : Array(items.filter { description($0).localizedCaseInsensitiveContains(searchText) })
    }

    @ViewBuilder
    private var buttonToggleAll: some View {
        Button(selection.isEmpty ? "Select All" : "Deselect All") {
            selection = selection.isEmpty ? Set(items.map { $0[keyPath: id] }) : []
        }
        .foregroundColor(.accentColor)
    }
}

#if DEBUG
@available(iOS 16, visionOS 1, *)
struct ConsoleSearchListSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleSearchListSelectionViewDemo()
            .frame(width: 320)
    }
}

@available(iOS 16, visionOS 1, *)
private struct ConsoleSearchListSelectionViewDemo: View {
    @State private var selection: Set<String>  = []

    var body: some View {
        List {
            ConsoleSearchListSelectionView(
                title: "Labels",
                items: ["Debug", "Warning", "Error"],
                id: \.self,
                selection: $selection,
                description: { $0 },
                label: { Text($0) }
            )
        }.listStyle(.plain)
    }
}
#endif

#endif

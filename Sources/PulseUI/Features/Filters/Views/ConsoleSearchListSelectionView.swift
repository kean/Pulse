// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

@available(iOS 15, *)
struct ConsoleSearchListSelectionView<Data: RandomAccessCollection, ID: Hashable, Label: View>: View {
    let title: String
    let items: Data
    let id: KeyPath<Data.Element, ID>
    @Binding var selection: Set<ID>
    let description: (Data.Element) -> String
    @ViewBuilder let label: (Data.Element) -> Label

#if os(iOS) || os(macOS)
    var limit = 6
#else
    var limit = 3
#endif

    @State private var searchText = ""

#if os(macOS)
    @State private var isExpanded = false

    var body: some View {
        if items.isEmpty {
            emptyView
        } else {
            let filtered = self.filteredItems
            HStack {
                SearchBar(title: "Search", text: $searchText)
                Spacer()
                buttonToggleAll
            }
            ForEach(isExpanded ? filtered : Array(filtered.prefix(limit)), id: id, content: makeRow)
            if filtered.count > limit {
                HStack {
                    if !isExpanded {
                        Button(action: { isExpanded = true }) {
                            Text("Show All ") + Text("(\(items.count))").foregroundColor(.secondary)
                        }
                    } else {
                        Button("Show Less") { isExpanded = false }
                    }
                }
            }
        }
    }
#else
    @State private var isExpandedListPresented = false
    @State private var isSearching = false

    var body: some View {
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
                    Text("View All").foregroundColor(.blue)
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
#if os(iOS)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .disableAutocorrection(true)
#else
        .searchable(text: $searchText)
        .disableAutocorrection(true)
#endif
    }
#endif

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
#if os(macOS)
        .help(description(item))
        .frame(maxWidth: .infinity, alignment: .leading)
#endif
    }

    private var filteredItems: [Data.Element] {
        searchText.isEmpty ? Array(items) : Array(items.filter { description($0).localizedCaseInsensitiveContains(searchText) })
    }

    @ViewBuilder
    private var buttonToggleAll: some View {
        Button(selection.isEmpty ? "Select All" : "Deselect All") {
            selection = selection.isEmpty ? Set(items.map { $0[keyPath: id] }) : []
        }
        .foregroundColor(.blue)
    }
}

#if DEBUG
@available(iOS 15, *)
struct ConsoleSearchListSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleSearchListSelectionViewDemo()
            .frame(width: 320)
    }
}

@available(iOS 15, *)
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

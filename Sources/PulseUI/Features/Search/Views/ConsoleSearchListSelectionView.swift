// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleSearchListSelectionView<Element: Hashable, Label: View>: View {
    let title: String
    let items: [Element]
    var limit = 4
    @Binding var selection: Set<Element>
    let description: (Element) -> String
    @ViewBuilder let label: (Element) -> Label
    @State private var searchText = ""
    @State private var isExpanded = false

#warning("TODO: refactor (use filteredItems for both lists and apply expand (?)")
#warning("TODO: improve how show more looks on macos")
#warning("TODO: macos show search only when expanded? or allow to search without expanding - that would be cool")
#warning("TODO: is .separator color OK?")

    var body: some View {
        if items.isEmpty {
            emptyView
        } else {
            let prefix = isExpanded ? items : Array(items.prefix(limit))
#if os(macOS)
            HStack {

                //                if !isExpanded {
                SearchBar(title: "Search", text: $searchText)
//                    .frame(width: 140)
                //                }
                Spacer()
                buttonToggleAll
            }
#endif
            ForEach(prefix, id: \.self, content: makeRow)
            if items.count > 4 {
#if os(macOS)
                HStack {
                    if !isExpanded {
                        Button(action: { isExpanded = true }) {
                            Text("Show More ") + Text("(\(items.count))").foregroundColor(.secondary)
                        }
                    } else {
                        Button("Show Less") { isExpanded = false }
                    }
                }
#else
                NavigationLink(destination: fullListBody) {
                    HStack {
                        Text("View All")
                        Spacer()
                        Text("\(items.count) ").foregroundColor(.separator)
                    }
                }
#endif
            }
        }
    }

    private var emptyView: some View {
        Text("Empty")
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundColor(.secondary)
    }

    private func makeRow(for item: Element) -> some View {
        Checkbox(isOn: Binding(get: {
            selection.contains(item)
        }, set: { isOn in
            if isOn {
                selection.insert(item)
            } else {
                selection.remove(item)
            }
        }), label: { label(item) })
#if os(macOS)
        .frame(maxWidth: .infinity, alignment: .leading)
#endif
    }

    @ViewBuilder
    private var fullListBody: some View {
        if #available(iOS 15, tvOS 15, *) {
            fullListForm
#if os(iOS)
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
#else
                .searchable(text: $searchText)
#endif
        } else {
            fullListForm
        }
    }

    @ViewBuilder
    private var fullListForm: some View {
        EmptyView()
        Form {
            buttonToggleAll
            ForEach(filteredItems, id: \.self, content: makeRow)
        }
        .inlineNavigationTitle(title)
    }

    private var filteredItems: [Element] {
        searchText.isEmpty ? items : items.filter { description($0).localizedCaseInsensitiveContains(searchText) }
    }

#warning("do we really need this? (accentColor?)")
    @ViewBuilder
    private var buttonToggleAll: some View {
        Button(selection.isEmpty ? "Enable All" : "Disable All") {
            selection = selection.isEmpty ? Set(items) : []
        }
#if !os(watchOS)
        .foregroundColor(.accentColor)
#endif
    }
}

extension ConsoleSearchListSelectionView where Element == String, Label == Text {
    init(title: String,
         items: [String],
         limit: Int = 4,
         selection: Binding<Set<String>>,
         @ViewBuilder label: @escaping (Element) -> Text = { Text($0) }) {
        self.title = title
        self.items = items
        self.limit = limit
        self._selection = selection
        self.description = { $0 }
        self.label = label
    }
}

#if DEBUG
struct ConsoleSearchListSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConsoleSearchListSelectionViewDemo()
        }
    }
}

private struct ConsoleSearchListSelectionViewDemo: View {
    @State private var selection: Set<String>  = []

    var body: some View {
        ConsoleSearchListSelectionView(title: "Labels", items: ["Debug", "Warning", "Error"], selection: $selection)
    }
}
#endif

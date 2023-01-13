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

    var body: some View {
        if items.isEmpty {
            Text("Empty")
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.secondary)
        } else {
            let prefix = isExpanded ? items : Array(items.prefix(limit))
            ForEach(prefix, id: \.self, content: makeRow)
            if items.count > 4 {
#if os(macOS)
                if !isExpanded {
                    Button(action: { isExpanded = true }) {
                        Text("Show More") + Text("\(items.count)").foregroundColor(.separator)
                    }
                } else {
                    Button("Show Less") { isExpanded = false }
                }
#else
                NavigationLink(destination: fullListBody) {
                    HStack {
                        Text("View All")
                        Spacer()
                        Text("\(items.count)").foregroundColor(.separator)
                    }
                }
#endif
            }
        }
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
            Button(selection.isEmpty ? "Enable All" : "Disable All") {
                selection = selection.isEmpty ? Set(items) : []
            }
#if !os(watchOS)
            .foregroundColor(.accentColor)
#endif
            ForEach(filteredItems, id: \.self, content: makeRow)
        }
        .inlineNavigationTitle(title)
    }

    private var filteredItems: [Element] {
        searchText.isEmpty ? items : items.filter { description($0).localizedCaseInsensitiveContains(searchText) }
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

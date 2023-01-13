// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS) || os(tvOS) || os(watchOS)

struct ConsoleSearchListSelectionView<Element: Hashable, Label: View>: View {
    let title: String
    let items: [Element]
    var limit: Int = 4
    @Binding var selection: Set<Element>
    let description: (Element) -> String
    @ViewBuilder let label: (Element) -> Label
    @State private var searchText = ""

    var body: some View {
        if items.isEmpty {
            Text("Empty")
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.secondary)
        } else {
            ForEach(items.prefix(limit), id: \.self, content: makeRow)
            if items.count > 4 {
                NavigationLink(destination: fullListBody) {
                    HStack {
                        Text("View All")
                        Spacer()
                        Text("\(items.count)").foregroundColor(.separator)
                    }
                }
            }
        }
    }

    private func makeRow(for item: Element) -> Checkbox<Label> {
        Checkbox(isOn: Binding(get: {
            selection.contains(item)
        }, set: { isOn in
            if isOn {
                selection.insert(item)
            } else {
                selection.remove(item)
            }
        }), label: { label(item) })
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

#endif

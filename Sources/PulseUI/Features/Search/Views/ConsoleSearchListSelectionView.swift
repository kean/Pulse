// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS) || os(tvOS) || os(watchOS)

struct ConsoleSearchListSelectionView: View {
    let title: String
    let items: [String]
    @Binding var selection: Set<String>

    @State private var searchText = ""

    var body: some View {
        if #available(iOS 15, tvOS 15, *) {
            form
#if os(iOS)
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
#else
                .searchable(text: $searchText)
#endif
        } else {
            form
        }
    }

    @ViewBuilder
    private var form: some View {
        Form {
            Button(selection.isEmpty ? "Enable All" : "Disable All") {
                selection = selection.isEmpty ? Set(items) : []
            }
#if !os(watchOS)
            .foregroundColor(.accentColor)
#endif

            ForEach(filteredItems, id: \.self) { item in
                Checkbox(item.capitalized, isOn: Binding(get: {
                    selection.contains(item)
                }, set: { isOn in
                    if isOn {
                        selection.insert(item)
                    } else {
                        selection.remove(item)
                    }
                }))
            }
        }
        .inlineNavigationTitle(title)
    }

    private var filteredItems: [String] {
        return searchText.isEmpty ? items : items.filter { $0.localizedCaseInsensitiveContains(searchText) }
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

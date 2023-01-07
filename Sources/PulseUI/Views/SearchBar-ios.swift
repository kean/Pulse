// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS)

struct SearchBar: UIViewRepresentable {
    let title: String
    @Binding var text: String
    @Binding var isSearching: Bool
    var onEditingChanged: ((_ isEditing: Bool) -> Void)?
    var inputAccessoryView: UIView?

    final class Coordinator: NSObject, UISearchBarDelegate {
        @Binding var text: String
        @Binding var isSearching: Bool
        let onEditingChanged: ((_ isEditing: Bool) -> Void)?

        init(text: Binding<String>,
             isSearching: Binding<Bool>,
             onEditingChanged: ((_ isEditing: Bool) -> Void)?) {
            self._text = text
            self._isSearching = isSearching
            self.onEditingChanged = onEditingChanged
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            self.text = searchText
        }

        func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            self.isSearching = true
            self.onEditingChanged?(true)
        }

        func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
            if self.isSearching != false {
                self.isSearching = false
            }
            self.onEditingChanged?(false)
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isSearching: $isSearching, onEditingChanged: onEditingChanged)
    }

    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar()
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = context.coordinator
        searchBar.spellCheckingType = .no
        searchBar.inputAccessoryView = inputAccessoryView
        return searchBar
    }

    func updateUIView(_ searchBar: UISearchBar, context: Context) {
        searchBar.placeholder = title
        searchBar.text = text
        if !isSearching {
            searchBar.resignFirstResponder()
        }
    }
}

#endif

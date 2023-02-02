// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI

struct RichTextViewSearchToobar: View {
    @ObservedObject var viewModel: RichTextViewModel

    var body: some View {
        HStack {
            SearchBar(title: "Search", text: $viewModel.searchTerm, onEditingChanged: { isEditing in
                if isEditing {
                    viewModel.isSearching = isEditing
                }
            }, onReturn: viewModel.nextMatch).frame(maxWidth: 240)

            StringSearchOptionsMenu(options: $viewModel.searchOptions, isKindNeeded: false)
                .fixedSize()

            Spacer()

            if !viewModel.matches.isEmpty {
                HStack(spacing: 12) {
                    Text(viewModel.matches.isEmpty ? "0/0" : "\(viewModel.selectedMatchIndex+1)/\(viewModel.matches.count)")
                        .font(Font.body.monospacedDigit())
                        .foregroundColor(.secondary)
                    Button(action: viewModel.previousMatch) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.matches.isEmpty)
                    Button(action: viewModel.nextMatch) {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.matches.isEmpty)
                }
                .fixedSize()
            }
        }
        .padding(6)
    }
}

#endif

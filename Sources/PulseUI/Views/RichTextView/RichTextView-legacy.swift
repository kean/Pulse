// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS)
struct LegacyRichTextView: View {
    @ObservedObject var viewModel: RichTextViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                searchBar
            }
            .padding(EdgeInsets(top: -2, leading: 4, bottom: -2, trailing: 6))

            WrappedTextView(viewModel: viewModel)
                .edgesIgnoringSafeArea(.bottom)
            if viewModel.isSearching {
                LegacyRichTextViewSearchToobar(viewModel: viewModel)
            }
        }
    }

    private var searchBar: some View {
        SearchBar(title: "Search", text: $viewModel.searchTerm, isSearching: $viewModel.isSearching)
    }
}
#endif

#if os(iOS) || os(macOS)
struct LegacyRichTextViewSearchToobar: View {
    @ObservedObject var viewModel: RichTextViewModel

#if os(iOS)
    var body: some View {
        HStack(alignment: .center) {
            Menu(content: {
                StringSearchOptionsMenu(options: $viewModel.searchOptions, isKindNeeded: false)
            }, label: {
                Text("Options")
            }).fixedSize()

            Spacer()

            HStack(spacing: 12) {
                Button(action: viewModel.previousMatch) {
                    Image(systemName: "chevron.left.circle")
                        .font(.system(size: 20))
                }.disabled(viewModel.matches.isEmpty)
                Text(viewModel.matches.isEmpty ? "0 of 0" : "\(viewModel.selectedMatchIndex+1) of \(viewModel.matches.count)")
                    .font(Font.body.monospacedDigit())
                Button(action: viewModel.nextMatch) {
                    Image(systemName: "chevron.right.circle")
                        .font(.system(size: 20))
                }.disabled(viewModel.matches.isEmpty)
            }
            .fixedSize()

            Spacer()

            Button(action: viewModel.cancelSearch) {
                Text("Cancel")
            }.fixedSize()
        }
        .padding(12)
    }
#else
    var body: some View {
        HStack {
            SearchBar(title: "Search", text: $viewModel.searchTerm, onEditingChanged: { isEditing in
                if isEditing {
                    viewModel.isSearching = isEditing
                }
            }, onReturn: viewModel.nextMatch).frame(maxWidth: 240)

            Menu(content: {
                StringSearchOptionsMenu(options: $viewModel.searchOptions, isKindNeeded: false)
            }, label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .frame(width: 40, height: 44)
            })
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

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
        .padding(6)
    }
#endif
}
#endif

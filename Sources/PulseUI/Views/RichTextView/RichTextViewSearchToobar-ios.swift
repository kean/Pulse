// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import SwiftUI

@available(iOS 15, *)
struct RichTextViewSearchToobar: View {
    @ObservedObject var viewModel: RichTextViewModel

    @State private var isRealMenuShown = false

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            options
            stepper
        }
        .padding(12)
        .background(Material.regular)
        .cornerRadius(8)
        .onReceive(Keyboard.isHidden) { isKeyboardHidden in
            // Show a non-interactive placeholder during animation,
            // then show the actual menu when navigation is settled.
            withAnimation(nil) {
                isRealMenuShown = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(750)) {
                withAnimation(nil) {
                    isRealMenuShown = true
                }
            }
        }
    }

    private var options: some View {
        ZStack {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(.accentColor)
                .font(.system(size: 20))
                .opacity(isRealMenuShown ? 0 : 1)
            if isRealMenuShown {
                Menu(content: {
                    StringSearchOptionsMenu(options: $viewModel.searchOptions, isKindNeeded: false)
                }, label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                })
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }

    private var stepper: some View {
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
    }
}

#endif

// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS)

import SwiftUI

struct RichTextViewSearchToobar: View {
    @ObservedObject var viewModel: RichTextViewModel

    @State private var isRealMenuShown = false

    var body: some View {
        Group {
            if #available(iOS 26, visionOS 26, *) {
                glassBar
            } else {
                legacyBar
            }
        }
        .onReceive(Keyboard.isHidden) { _ in
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

    private var matchCountText: String {
        viewModel.matches.isEmpty ? "0 of 0" : "\(viewModel.selectedMatchIndex + 1) of \(viewModel.matches.count)"
    }

    // MARK: iOS 26 (Liquid Glass)

    @available(iOS 26, visionOS 26, *)
    private var glassBar: some View {
        HStack(spacing: 2) {
            navButton("chevron.left", action: viewModel.previousMatch)

            Text(matchCountText)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                // Reserve enough room for common counts so the chevrons don't
                // shift as matches update; very large counts scale down.
                .frame(minWidth: 64, alignment: .center)

            navButton("chevron.right", action: viewModel.nextMatch)

            moreMenu
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 26))
    }

    @available(iOS 26, visionOS 26, *)
    private func navButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.matches.isEmpty)
    }

    @available(iOS 26, visionOS 26, *)
    @ViewBuilder
    private var moreMenu: some View {
        ZStack {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .medium))
                .opacity(isRealMenuShown ? 0 : 1)
            if isRealMenuShown {
                Menu(content: {
                    StringSearchOptionsMenu(options: $viewModel.searchOptions, isKindNeeded: false)
                }, label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                })
                .menuStyle(.borderlessButton)
            }
        }
        .frame(width: 40, height: 40)
    }

    // MARK: Legacy (iOS < 26)

    private var legacyBar: some View {
        HStack(alignment: .center, spacing: 24) {
            legacyOptions
            legacyStepper
        }
        .padding(12)
        .background(Material.regular)
        .cornerRadius(8)
    }

    private var legacyOptions: some View {
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

    private var legacyStepper: some View {
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

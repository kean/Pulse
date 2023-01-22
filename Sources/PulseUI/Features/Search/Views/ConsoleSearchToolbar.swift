// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

#if os(iOS)

@available(iOS 15, *)
struct ConsoleSearchToolbar: View {
    let title: String
    var isSpinnerNeeded = false
    @ObservedObject var viewModel: ConsoleViewModel

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(title)
                .foregroundColor(.secondary)
                .font(.subheadline.weight(.medium))
            if isSpinnerNeeded {
                ProgressView()
                    .padding(.leading, 8)
            }
            Spacer()
            HStack(spacing: 14) {
                Menu(content: { shareMenu }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
                ConsoleSearchContextMenu(viewModel: viewModel.searchViewModel)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var shareMenu: some View {
        Button(action: { share(as: .plainText) }) {
            Label("Share as Text", systemImage: "square.and.arrow.up")
        }
        Button(action: { share(as: .html) }) {
            Label("Share as HTML", systemImage: "square.and.arrow.up")
        }
    }

    private func share(as output: ShareOutput) {
        viewModel.prepareForSharing(as: output) { item in
            viewModel.router.shareItems = item
        }
    }
}
#endif

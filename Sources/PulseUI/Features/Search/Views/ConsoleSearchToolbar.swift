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
                ConsoleSearchContextMenu(viewModel: viewModel.searchViewModel)
                ConsoleFiltersView(viewModel: viewModel, isShowingFilters: $viewModel.isShowingFilters)
            }
        }
        .buttonStyle(.plain)
    }
}
#endif

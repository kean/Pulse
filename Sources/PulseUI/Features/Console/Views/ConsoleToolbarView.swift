// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

#if os(iOS)

struct ConsoleToolbarView: View {
    let title: String
    @ObservedObject var viewModel: ConsoleViewModel

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(title)
                .foregroundColor(.secondary)
                .font(.subheadline.weight(.medium))
            Spacer()
            HStack(spacing: 14) {
                ConsoleFiltersView(isNetworkModeEnabled: viewModel.isNetworkModeEnabled, viewModel: viewModel.searchCriteriaViewModel, isShowingFilters: $viewModel.isShowingFilters)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ConsoleFiltersView: View {
    let isNetworkModeEnabled: Bool
    @ObservedObject var viewModel: ConsoleSearchCriteriaViewModel
    @Binding var isShowingFilters: Bool

    var body: some View {
        if !isNetworkModeEnabled {
            Button(action: { viewModel.isOnlyNetwork.toggle() }) {
                Image(systemName: viewModel.isOnlyNetwork ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
            }
        }
        Button(action: { viewModel.isOnlyErrors.toggle() }) {
            Image(systemName: viewModel.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
                .font(.system(size: 20))
                .foregroundColor(viewModel.isOnlyErrors ? .red : .accentColor)
        }
        Button(action: { isShowingFilters = true }) {
            Image(systemName: viewModel.isCriteriaDefault ? "line.horizontal.3.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
        }
    }
}

#endif

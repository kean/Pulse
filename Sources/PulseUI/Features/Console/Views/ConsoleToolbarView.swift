// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

#if os(iOS)

#warning("add keyboard shortcuts")

struct ConsoleFiltersView: View {
    @ObservedObject var viewModel: ConsoleViewModel
    @State private var isShowingFilters = false

    var body: some View {
        HStack(spacing: 16) {
            if !viewModel.isNetworkOnly {
                Button(action: viewModel.toggleMode) {
                    Image(systemName: viewModel.mode == .network ? "arrow.down.circle.fill" : "arrow.down.circle")
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
                Image(systemName: viewModel.searchCriteriaViewModel.isCriteriaDefault ? "line.horizontal.3.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
            }
        }
        .sheet(isPresented: $isShowingFilters) {
            NavigationView {
                ConsoleSearchCriteriaView(viewModel: viewModel.searchCriteriaViewModel)
                    .inlineNavigationTitle("Filters")
                    .navigationBarItems(trailing: Button("Done") { isShowingFilters = false })
            }
        }
    }
}

#endif

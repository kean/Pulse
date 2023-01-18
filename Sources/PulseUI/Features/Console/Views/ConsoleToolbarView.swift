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

    @State private var isShowingFilters = false
    @State private var messageCount = 0
    @State private var isSearching = false

    var body: some View {
        VStack {
            HStack(spacing: 0) {
                Text(title)
                    .foregroundColor(.secondary)
                Spacer()
                filters
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)
            .padding(.top, -10)
        }
        .sheet(isPresented: $isShowingFilters) {
            NavigationView {
                ConsoleSearchCriteriaView(viewModel: viewModel.searchCriteriaViewModel)
                    .inlineNavigationTitle("Filters")
                    .navigationBarItems(trailing: Button("Done") { isShowingFilters = false })
            }
        }
    }

    @ViewBuilder
    private var filters: some View {
        if !viewModel.isNetworkOnly {
            Button(action: viewModel.toggleMode) {
                Image(systemName: viewModel.mode == .network ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
            }.frame(width: 40)
        }
        Button(action: { viewModel.isOnlyErrors.toggle() }) {
            Image(systemName: viewModel.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
                .font(.system(size: 20))
                .foregroundColor(viewModel.isOnlyErrors ? .red : .accentColor)
        }.frame(width: 40)
        Button(action: { isShowingFilters = true }) {
            Image(systemName: viewModel.searchCriteriaViewModel.isCriteriaDefault ? "line.horizontal.3.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
        }.frame(width: 40)
    }
}
#endif

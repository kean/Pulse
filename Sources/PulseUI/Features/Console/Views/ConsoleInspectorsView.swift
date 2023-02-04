// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct ConsoleInspectorsView: View {
    let viewModel: ConsoleViewModel
    @State private var selectedTab: ConsoleInspector = .storeInfo

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            selectedTabView
        }
    }

    private var toolbar: some View {
        HStack {
            Spacer()
            ForEach(ConsoleInspector.allCases) { item in
                TabBarItem(image: Image(systemName: item.systemImage), isSelected: item == selectedTab) {
                    selectedTab = item
                }
            }
            Spacer()
        }.padding(EdgeInsets(top: 4, leading: 10, bottom: 5, trailing: 8))
    }

    @ViewBuilder
    private var selectedTabView: some View {
        switch selectedTab {
        case .filters:
            ConsoleSearchCriteriaView(viewModel: viewModel.searchCriteriaViewModel)
        case .storeInfo:
            StoreDetailsView(source: .store(viewModel.store))
                .padding()
        }
    }
}

private enum ConsoleInspector: Identifiable, CaseIterable {
    case filters
    case storeInfo

    var id: ConsoleInspector { self }

    var systemImage: String {
        switch self {
        case .filters:
            return "line.3.horizontal.decrease.circle"
        case .storeInfo:
            return "info.circle"
        }
    }
}

private struct TabBarItem: View {
    let image: Image
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            image
                .foregroundColor(isSelected ? .primary : .secondary)
                .padding(2)
                .padding(.horizontal, 2)
                .onHover { isHovering = $0 }
                .background(isSelected ? Color.blue.opacity(0.8) : (isHovering ? Color.blue.opacity(0.25) : nil))
                .cornerRadius(4)
        }.buttonStyle(.plain)
    }
}

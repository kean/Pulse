// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI

struct ConsoleInspectorsView: View {
    @EnvironmentObject private var viewModel: ConsoleEnvironment

    @State private var selectedTab: ConsoleInspector = .filters

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().opacity(0.8)
            selectedTabView
        }
    }

    private var inspectors: [ConsoleInspector] {
        var inspectors = ConsoleInspector.allCases
        if viewModel.store.isArchive {
            inspectors.removeAll(where: { $0 == .settings })
        }
        if #unavailable(macOS 13) {
            inspectors.removeAll(where: { $0 == .sessions })
        }
        return inspectors
    }

    private var toolbar: some View {
        HStack(alignment: .center) {
            Spacer()
            ForEach(inspectors) { item in
                TabBarItem(image: Image(systemName: item.systemImage), isSelected: item == selectedTab) {
                    selectedTab = item
                }
            }
            Spacer()
        }
        .offset(y: -2)
        .frame(height: 27, alignment: .center)
    }

    @ViewBuilder
    private var selectedTabView: some View {
        switch selectedTab {
        case .filters:
            ConsoleFiltersView()
        case .storeInfo:
            VStack {
                StoreDetailsView(source: .store(viewModel.store))
                Spacer()
            }
        case .settings:
            VStack {
                SettingsView(store: viewModel.store)
                Spacer()
            }
        case .sessions:
            if #available(macOS 13, *) {
                SessionsView()
            }
        }
    }
}

private enum ConsoleInspector: Identifiable, CaseIterable {
    case filters
    case storeInfo
    case settings
    case sessions

    var id: ConsoleInspector { self }

    var systemImage: String {
        switch self {
        case .filters:
            return "line.3.horizontal.decrease.circle"
        case .storeInfo:
            return "info.circle"
        case .settings:
            return "gearshape"
        case .sessions:
            return "list.clipboard"
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
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(2)
                .padding(.horizontal, 2)
                .onHover { isHovering = $0 }
                .background(isSelected ? Color.blue.opacity(0.8) : (isHovering ? Color.blue.opacity(0.25) : nil))
                .cornerRadius(4)
        }.buttonStyle(.plain)
    }
}

#endif

// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(macOS)

public struct MainView: View {
    @StateObject private var model: MainViewModel
    
    public init(store: LoggerStore = .default) {
        self._model = StateObject(wrappedValue: MainViewModel(store: store, onDismiss: nil))
    }

    public var body: some View {
        NavigationView {
            SidebarView(model: model)
                .frame(minWidth: 150)
                .toolbar {
                    ToolbarItem(placement: ToolbarItemPlacement.status) {
                        Button(action: toggleSidebar) {
                            Label("Back", systemImage: "sidebar.left")
                        }
                    }
                }
            Text("No Tab Selected") // Should never happen
            Text("No Selection")
                .font(.title)
                .foregroundColor(.secondary)
                .toolbar(content: {
                    Spacer()
                })
        }
    }
}

private func toggleSidebar() {
    NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
}

private struct SidebarView: View {
    @ObservedObject private var model: MainViewModel
    @ObservedObject private var consoleModel: ConsoleViewModel
    @ObservedObject private var networkModel: ConsoleViewModel
    @ObservedObject private var pinsModel: ConsoleViewModel

    @State private var isConsoleTabSelected = true
    @State private var isNetwokTabSelected = false
    @State private var isPinsTabSelected = false
    
    init(model: MainViewModel) {
        self.model = model
        self.consoleModel = model.consoleModel
        self.networkModel = model.networkModel
        self.pinsModel = model.pinsModel

        // Preload share services
        _ = ShareMenuContentViewModel.url
    }

    var body: some View {
        List {
            SiderbarSectionTitle(text: "Menu")
            NavigationLink(destination: ConsoleView(model: model.consoleModel), isActive: $isConsoleTabSelected) {
                SidebarNavigationTab(item: .console, count: consoleModel.messages.count)
            }
            NavigationLink(destination: NetworkView(model: model.networkModel), isActive: $isNetwokTabSelected) {
                SidebarNavigationTab(item: .network, count: networkModel.messages.count)
            }
            NavigationLink(destination: PinsView(model: model.pinsModel), isActive: $isPinsTabSelected) {
                SidebarNavigationTab(item: .pins, count: pinsModel.messages.count)
            }
            
            if isConsoleTabSelected {
                SidebarFiltersSectionView(model: consoleModel, type: .default)
            } else if isNetwokTabSelected {
                SidebarFiltersSectionView(model: networkModel, type: .network)
            }
        }.listStyle(SidebarListStyle())
    }
}

struct SiderbarSectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(Color.secondary.opacity(0.8))
    }
}

private struct SidebarNavigationTab: View {
    let item: MainViewModelItem
    let count: Int

    var body: some View {
        HStack {
            Label(item.title, systemImage: item.imageName)
            Spacer()
            BadgeView(model: .init(title: count.description, color: .accentColor), cornerRadius: 20)
        }
    }
}

private struct SidebarFiltersSectionView: View {
    @ObservedObject var model: ConsoleViewModel
    let type: ConsoleFiltersViewType

    var body: some View {
        ConsoleFiltersView(model: model, type: type)

        if !model.quickFilters.isEmpty {
            SiderbarSectionTitle(text: "Quick Filters")
                .padding(.top, 16)

            ConsoleQuickFiltersView(filters: model.quickFilters)
        }
    }
}

#endif

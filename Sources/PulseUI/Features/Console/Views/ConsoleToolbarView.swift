// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct ConsoleToolbarView: View {
    @EnvironmentObject private var environment: ConsoleEnvironment
    @EnvironmentObject private var filters: ConsoleFiltersViewModel
    @EnvironmentObject private var searchViewModel: ConsoleSearchViewModel
    @Environment(\.isSearching) private var isSearching

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 9) {
                ConsoleSessionsPill()
                ConsoleFilterPill(isSearching: isSearching)
            }
            Spacer(minLength: 9)
            HStack(spacing: 9) {
                ConsoleSortByPill()
                ConsoleGroupByPill()
                ConsoleOnlyErrorsButton(isEnabled: $filters.options.isOnlyErrors)
                if isSearching {
                    ConsoleSearchContextMenu(viewModel: searchViewModel)
                        .transition(.scale(scale: 0.3, anchor: .trailing).combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .animation(.snappy, value: filters.options.isOnlyErrors)
        .animation(.snappy, value: filters.options.filters)
        .animation(.snappy, value: environment.listOptions)
        .animation(.snappy, value: searchViewModel.options)
        .animation(.snappy, value: searchViewModel.scopes)
        .animation(.snappy, value: isSearching)
    }
}

private let consolePillResetXmarkWidth: CGFloat = 24

@available(iOS 18, tvOS 18, macOS 15, visionOS 1, *)
private struct ConsolePillResetXmark: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.85))
                .padding(.leading, 2)
                .padding(.trailing, 8)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Wraps a Button-style trigger in the standard console pill background,
/// optionally appending a reset xmark button when `isActive` and `resetAction` is set.
@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
private struct ConsoleTogglePill<Trigger: View>: View {
    let isActive: Bool
    var activeColor: Color = .accentColor
    let resetAction: (() -> Void)?
    @ViewBuilder let trigger: () -> Trigger

    private var hasReset: Bool { isActive && resetAction != nil }

    var body: some View {
        HStack(spacing: 0) {
            trigger()
                .padding(.leading, 9)
                .padding(.vertical, 8)
                .padding(.trailing, hasReset ? 4 : 8)
            if let resetAction, isActive {
                ConsolePillResetXmark(action: resetAction)
            }
        }
        .frame(minWidth: 34) // Never narrower than tall — keep at least square
        .toolbarPillBackground(isActive: isActive, activeColor: activeColor)
        .animation(.snappy, value: isActive)
    }
}

/// A pill whose entire surface is the label of a Menu, so tapping anywhere on the
/// pill opens the menu. When `resetAction` is non-nil and `isActive`, an xmark
/// reset button is overlaid on the trailing edge with its own tap area.
@available(iOS 18, tvOS 18, macOS 15, visionOS 1, *)
private struct ConsoleMenuPill<MenuContent: View>: View {
    let systemImage: String
    var title: String? = nil
    let isActive: Bool
    let resetAction: (() -> Void)?
    @ViewBuilder let menuContent: () -> MenuContent

    private var hasReset: Bool { isActive && resetAction != nil }

    var body: some View {
        Menu {
            menuContent()
        } label: {
            HStack(spacing: 0) {
                ToolbarPillLabel(title: title, systemImage: systemImage, isActive: isActive)
                    .padding(.leading, 9)
                    .padding(.vertical, 8)
                    .padding(.trailing, hasReset ? 4 : 8)
                if hasReset {
                    // Reserve space for the overlayed xmark button so the menu
                    // label visually leaves room for it.
                    Color.clear
                        .frame(width: consolePillResetXmarkWidth, height: 1)
                }
            }
            .frame(minWidth: 34) // Never narrower than tall — keep at least square
            .toolbarPillBackground(isActive: isActive)
            .animation(.snappy, value: isActive)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            if let resetAction, isActive {
                ConsolePillResetXmark(action: resetAction)
            }
        }
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
private struct ConsoleFilterPill: View {
    let isSearching: Bool

    @EnvironmentObject private var environment: ConsoleEnvironment
    @EnvironmentObject private var filters: ConsoleFiltersViewModel

    private var isActive: Bool {
        !filters.isDefaultFilters(for: filters.mode)
    }

    var body: some View {
        ConsoleTogglePill(isActive: isActive, resetAction: resetFilters) {
            Button(action: openFilters) {
                ToolbarPillLabel(
                    title: "Filters",
                    systemImage: "line.3.horizontal.decrease",
                    isActive: isActive
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func openFilters() {
        environment.router.isShowingFilters = true
    }

    private func resetFilters() {
        filters.resetAll()
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
package struct ConsoleOnlyErrorsButton: View {
    @Binding package var isEnabled: Bool

    package init(isEnabled: Binding<Bool>) {
        self._isEnabled = isEnabled
    }

    package var body: some View {
        ConsoleTogglePill(isActive: isEnabled, activeColor: .red, resetAction: nil) {
            Button(action: { isEnabled.toggle() }) {
                ToolbarPillLabel(
                    systemImage: isEnabled ? "exclamationmark.octagon.fill" : "exclamationmark.octagon",
                    isActive: isEnabled
                )
            }
            .buttonStyle(.plain)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
private struct ConsoleSessionsPill: View {
    @EnvironmentObject private var environment: ConsoleEnvironment
    @EnvironmentObject private var filters: ConsoleFiltersViewModel

    private var isActive: Bool {
        let selected = filters.options.sessions
        if let sessionID = environment.store.currentSessionID {
            return selected != [sessionID]
        }
        return !selected.isEmpty
    }

    var body: some View {
        ConsoleTogglePill(isActive: isActive, resetAction: nil) {
            Button(action: { environment.router.isShowingSessions = true }) {
                ToolbarPillLabel(
                    systemImage: "list.bullet.clipboard",
                    isActive: isActive
                )
            }
            .buttonStyle(.plain)
        }
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
private struct ConsoleSortByPill: View {
    @EnvironmentObject private var environment: ConsoleEnvironment

    private var isActive: Bool {
        if environment.mode == .network {
            return environment.listOptions.taskSortBy != .dateCreated
                || environment.listOptions.order != .descending
        } else {
            return environment.listOptions.messageSortBy != .dateCreated
                || environment.listOptions.order != .descending
        }
    }

    private var fieldLabel: String {
        environment.mode == .network
            ? environment.listOptions.taskSortBy.pillTitle
            : environment.listOptions.messageSortBy.pillTitle
    }

    var body: some View {
        ConsoleMenuPill(
            systemImage: environment.listOptions.order == .ascending ? "arrow.up" : "arrow.down",
            title: fieldLabel,
            isActive: isActive,
            resetAction: reset
        ) {
            ConsoleSortByMenuContent()
        }
    }

    private func reset() {
        environment.listOptions.order = .descending
        if environment.mode == .network {
            environment.listOptions.taskSortBy = .dateCreated
        } else {
            environment.listOptions.messageSortBy = .dateCreated
        }
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct ConsoleSortByMenuContent: View {
    @EnvironmentObject private var environment: ConsoleEnvironment

    var body: some View {
        if environment.mode == .network {
            Picker("Sort By", selection: $environment.listOptions.taskSortBy) {
                ForEach(ConsoleListOptions.TaskSortBy.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
        } else {
            Picker("Sort By", selection: $environment.listOptions.messageSortBy) {
                ForEach(ConsoleListOptions.MessageSortBy.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
        }
        Picker("Ordering", selection: $environment.listOptions.order) {
            Text("Descending").tag(ConsoleListOptions.Ordering.descending)
            Text("Ascending").tag(ConsoleListOptions.Ordering.ascending)
        }
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
package struct ConsoleSearchContextMenu<ViewModel: ConsoleSearchOptionsHost>: View {
    @ObservedObject var viewModel: ViewModel
    @State private var isPresented = false

    private var isOptionsActive: Bool {
        viewModel.options != .default
    }

    private var isScopesActive: Bool {
        viewModel.scopes != viewModel.savedDefaultScopes
    }

    private var isActive: Bool {
        isOptionsActive || isScopesActive
    }

    package init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    package var body: some View {
        ConsoleTogglePill(isActive: isActive, resetAction: isActive ? reset : nil) {
            Button {
                isPresented = true
            } label: {
                ToolbarPillLabel(
                    systemImage: "gearshape",
                    isActive: isActive
                )
            }
            .buttonStyle(.plain)
        }
#if os(iOS) || os(visionOS)
        .sheet(isPresented: $isPresented) {
            ConsoleSearchOptionsSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
#endif
    }

    private func reset() {
        viewModel.options = .default
        viewModel.resetScopesToDefault()
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
private struct ConsoleGroupByPill: View {
    @EnvironmentObject private var environment: ConsoleEnvironment
    @EnvironmentObject private var listViewModel: ConsoleListViewModel

    private var isActive: Bool {
        if environment.mode == .network {
            return environment.listOptions.taskGroupBy != .noGrouping
        } else {
            return environment.listOptions.messageGroupBy != .noGrouping
        }
    }

    var body: some View {
        if isActive {
            ConsoleMenuPill(
                systemImage: "rectangle.3.group",
                isActive: true,
                resetAction: nil
            ) {
                Section {
                    Button(action: listViewModel.collapseAllSections) {
                        Label("Collapse All", systemImage: "rectangle.compress.vertical")
                    }
                    Button(action: listViewModel.expandAllSections) {
                        Label("Expand All", systemImage: "rectangle.expand.vertical")
                    }
                }
                Section {
                    ConsoleRemoveGroupingButton()
                }
                Section {
                    ConsoleGroupByMenuContent()
                }
            }
            .transition(.scale.combined(with: .opacity))
        }
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct ConsoleGroupByMenuContent: View {
    @EnvironmentObject private var environment: ConsoleEnvironment

    var body: some View {
        if environment.mode == .network {
            Picker("Group By", selection: $environment.listOptions.taskGroupBy) {
                ForEach(ConsoleListOptions.TaskGroupBy.allCases.filter { $0 != .noGrouping }, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
        } else {
            Picker("Group By", selection: $environment.listOptions.messageGroupBy) {
                ForEach(ConsoleListOptions.MessageGroupBy.allCases.filter { $0 != .noGrouping }, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
        }
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct ConsoleRemoveGroupingButton: View {
    @EnvironmentObject private var environment: ConsoleEnvironment

    private var isActive: Bool {
        if environment.mode == .network {
            return environment.listOptions.taskGroupBy != .noGrouping
        } else {
            return environment.listOptions.messageGroupBy != .noGrouping
        }
    }

    var body: some View {
        if isActive {
            Button(role: .destructive, action: remove) {
                Label("Remove Grouping", systemImage: "list.bullet")
            }
        }
    }

    private func remove() {
        if environment.mode == .network {
            environment.listOptions.taskGroupBy = .noGrouping
        } else {
            environment.listOptions.messageGroupBy = .noGrouping
        }
    }
}

#endif

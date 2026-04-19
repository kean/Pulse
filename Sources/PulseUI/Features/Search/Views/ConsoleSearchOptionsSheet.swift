// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import SwiftUI
import Pulse

/// Abstracts the search options + scopes surface so that the same sheet can be
/// driven by either `ConsoleSearchViewModel` or `Rift_ConsoleSearchViewModel`.
@MainActor
@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
package protocol ConsoleSearchOptionsHost: ObservableObject {
    var options: StringSearchOptions { get set }
    var scopes: Set<ConsoleSearchScope> { get set }
    var savedDefaultScopes: Set<ConsoleSearchScope> { get }
    var availableLogScopes: [ConsoleSearchScope] { get }
    var availableNetworkScopes: [ConsoleSearchScope] { get }
    var defaultScopes: [ConsoleSearchScope] { get }
    func resetScopesToDefault()
    func saveCurrentScopesAsDefault()
}

#endif

#if os(iOS) || os(visionOS)

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
package struct ConsoleSearchOptionsSheet<ViewModel: ConsoleSearchOptionsHost>: View {
    @ObservedObject var viewModel: ViewModel
    @Environment(\.dismiss) private var dismiss

    private var isOptionsDefault: Bool {
        viewModel.options == .default
    }

    private var isScopesDefault: Bool {
        viewModel.scopes == Set(viewModel.defaultScopes)
    }

    private var canSaveAsDefault: Bool {
        viewModel.scopes != viewModel.savedDefaultScopes
    }

    package init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    package var body: some View {
        NavigationStack {
            Form {
                Section {
                    StringSearchCompactOptionsView(options: $viewModel.options)
                        .frame(height: 16)
                } header: {
                    ConsoleSearchSectionHeader(
                        icon: "magnifyingglass",
                        title: "Search Options",
                        isDefault: isOptionsDefault,
                        reset: { viewModel.options = .default }
                    )
                }
                scopesSection
            }
            .navigationTitle("Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .animation(.snappy, value: viewModel.options)
            .animation(.snappy, value: viewModel.scopes)
        }
    }

    @ViewBuilder
    private var scopesSection: some View {
        let scopes = viewModel.availableLogScopes + viewModel.availableNetworkScopes
        if !scopes.isEmpty {
            Section {
                ForEach(scopes, id: \.self) { scope in
                    scopeRow(scope)
                }
            } header: {
                ConsoleSearchSectionHeader(
                    icon: "target",
                    title: "Scopes",
                    isDefault: isScopesDefault,
                    reset: { viewModel.resetScopesToDefault() }
                ) {
                    if canSaveAsDefault {
                        Button("Save as Default") {
                            viewModel.saveCurrentScopesAsDefault()
                        }
                        .font(.subheadline)
                        .textCase(nil)
                    }
                }
            }
        }
    }

    private func scopeRow(_ scope: ConsoleSearchScope) -> some View {
        Checkbox(isOn: Binding(get: {
            viewModel.scopes.contains(scope)
        }, set: { isOn in
            if isOn {
                viewModel.scopes.insert(scope)
            } else {
                viewModel.scopes.remove(scope)
            }
        }), label: { Text(scope.title).lineLimit(1) })
    }
}

#endif

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, *)
struct ConsoleSearchToolbar: View {
    @EnvironmentObject private var viewModel: ConsoleSearchViewModel
    @State private var isShowingScopesPicker = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(viewModel.toolbarTitle)
                .foregroundColor(.secondary)
                .font(.subheadline.weight(.medium))
            if viewModel.isSpinnerNeeded {
                ProgressView()
                    .padding(.leading, 8)
            }
#if os(macOS)
            if viewModel.isNewResultsButtonShown {
                Button(action: viewModel.buttonShowNewlyAddedSearchResultsTapped) {
                    Text("Show New Results")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.link)
                .padding(.leading, 16)
            }
#endif
            Spacer()

            searchOptionsView
        }
        .buttonStyle(.plain)
#if os(macOS)
        .padding(.horizontal, 10)
        .frame(height: 27, alignment: .center)
#endif
    }

    private var searchOptionsView: some View {
#if os(iOS)
            HStack(spacing: 14) {
                ConsoleSearchContextMenu()
            }
#else
            HStack {
                ConsoleSearchStringOptionsView(viewModel: viewModel)
                ConsoleSearchPickScopesButton {
                    isShowingScopesPicker.toggle()
                }.popover(isPresented: $isShowingScopesPicker, arrowEdge: .top) {
                    ConsoleSearchScopesPicker(viewModel: viewModel)
                        .padding()
                }
            }
#endif
    }
}

#if os(macOS)
struct ConsoleSearchStringOptionsView: View {
    @ObservedObject var viewModel: ConsoleSearchViewModel

    var body: some View {
        HStack {
            Picker("Kind", selection: $viewModel.options.kind) {
                ForEach(StringSearchOptions.Kind.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .padding(.leading, -4)
            if let rules = viewModel.options.allEligibleMatchingRules() {
                Picker("Matching Rule", selection: $viewModel.options.rule) {
                    ForEach(rules, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
            }
            Picker("Case Sensitivity", selection: $viewModel.options.caseSensitivity) {
                ForEach(StringSearchOptions.CaseSensitivity.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
        }
        .opacity(0.8)
        .buttonStyle(.borderless)
        .pickerStyle(.menu)
        .menuStyle(.borderlessButton)
        .labelsHidden()
    }
}
#endif

@available(iOS 15, *)
struct ConsoleSearchScopesPicker: View {
    @ObservedObject var viewModel: ConsoleSearchViewModel

    var body: some View {
        ForEach(viewModel.allScopes, id: \.self) { scope in
            Checkbox(isOn: Binding(get: {
                viewModel.scopes.contains(scope)
            }, set: { isOn in
                if isOn {
                    viewModel.scopes.insert(scope)
                } else {
                    viewModel.scopes.remove(scope)
                }
            }), label: { Text(scope.title).lineLimit(1) })
    #if os(macOS)
            .frame(maxWidth: .infinity, alignment: .leading)
    #endif
        }
    }
}

@available(iOS 15, *)
struct ConsoleSearchPickScopesButton: View {
    @EnvironmentObject var viewModel: ConsoleSearchViewModel

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "target")
                Text("\(viewModel.scopes.count == 0 ? viewModel.allScopes.count : viewModel.scopes.count)")
                    .font(.body.monospacedDigit())
            }.foregroundColor(.secondary)
        }.buttonStyle(.plain)
    }
}
#endif

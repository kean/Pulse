// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, visionOS 1.0, *)
struct ConsoleSearchToolbar: View {
    @EnvironmentObject private var viewModel: ConsoleSearchViewModel

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(viewModel.toolbarTitle)
                .foregroundColor(.secondary)
                .font(.subheadline.weight(.medium))
            if viewModel.isSpinnerNeeded {
                ProgressView()
                    .padding(.leading, 8)
            }
            Spacer()
            searchOptionsView
        }
        .buttonStyle(.plain)
#if os(macOS)
        .padding(.horizontal)
        .frame(height: 34, alignment: .center)
#endif
    }

    private var searchOptionsView: some View {
#if os(iOS) || os(visionOS)
            HStack(spacing: 14) {
                ConsoleSearchContextMenu()
            }
#else
        StringSearchOptionsMenu(options: $viewModel.options)
            .fixedSize()
#endif
    }
}

@available(iOS 15, visionOS 1.0, *)
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
#endif

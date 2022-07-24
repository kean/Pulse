// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS) || os(macOS)

// MARK: - NetworkFiltersView (Networking)

extension NetworkFiltersView {
    @ViewBuilder
    var networkingGroup: some View {
        FiltersSection(
            isExpanded: $isRedirectGroupExpanded,
            header: { networkingGroupHeader },
            content: { networkingGroupContent }
        )
    }

    private var networkingGroupHeader: some View {
        FilterSectionHeader(
            icon: "arrowshape.zigzag.right", title: "Networking",
            color: .yellow,
            reset: { viewModel.criteria.networking = .default },
            isDefault: viewModel.criteria.networking == .default,
            isEnabled: $viewModel.criteria.networking.isEnabled
        )
    }

    @ViewBuilder
    private var networkingGroupContent: some View {
        Filters.taskTypePicker($viewModel.criteria.networking.taskType)
        Filters.responseSourcePicker($viewModel.criteria.networking.source)
        Filters.toggle("Redirect", isOn: $viewModel.criteria.networking.isRedirect)
    }
}

// MARK: - Helpers

private struct FiltersSection<Header: View, Content: View>: View {
    var isExpanded: Binding<Bool>
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    var body: some View {
#if os(iOS)
        Section(content: content, header: header)
#elseif os(macOS)
        DisclosureGroup(
            isExpanded: isExpanded,
            content: {
                VStack {
                    content()
                }
                .padding(.leading, 12)
                .padding(.trailing, 5)
                .padding(.top, Filters.contentTopInset)
            },
            label: header
        )
#endif
    }
}

private extension Filters {
    static func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
#if os(iOS)
        Toggle(title, isOn: isOn)
        #elseif os(macOS)
        HStack {
            Toggle(title, isOn: isOn)
            Spacer()
        }
        #endif
    }
}

#endif

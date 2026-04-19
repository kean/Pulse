// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI

package struct ConsoleSearchSectionHeader: View {
    let icon: String
    let title: String
    let reset: () -> Void
    let isDefault: Bool
    @Binding var isEnabled: Bool
    var accessory: AnyView?

    package init<Filter: ConsoleFilterGroupProtocol>(
        icon: String,
        title: String,
        filter: Binding<Filter>,
        default: Filter? = nil
    ) {
        self.icon = icon
        self.title = title
        self.reset = { filter.wrappedValue = `default` ?? Filter() }
        self.isDefault = filter.wrappedValue == `default` ?? Filter()
        self._isEnabled = filter.isEnabled
        self.accessory = nil
    }

    package init<Filter: ConsoleFilterGroupProtocol, Accessory: View>(
        icon: String,
        title: String,
        filter: Binding<Filter>,
        default: Filter? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.icon = icon
        self.title = title
        self.reset = { filter.wrappedValue = `default` ?? Filter() }
        self.isDefault = filter.wrappedValue == `default` ?? Filter()
        self._isEnabled = filter.isEnabled
        self.accessory = AnyView(accessory())
    }

    /// Plain initializer for headers that are not backed by a `ConsoleFilterGroupProtocol`
    /// filter (e.g. search options or scopes).
    package init(
        icon: String,
        title: String,
        isDefault: Bool,
        reset: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.reset = reset
        self.isDefault = isDefault
        self._isEnabled = .constant(true)
        self.accessory = nil
    }

    /// Plain initializer with an accessory view.
    package init<Accessory: View>(
        icon: String,
        title: String,
        isDefault: Bool,
        reset: @escaping () -> Void,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.icon = icon
        self.title = title
        self.reset = reset
        self.isDefault = isDefault
        self._isEnabled = .constant(true)
        self.accessory = AnyView(accessory())
    }

#if os(macOS)
    package var body: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                Text(title)
                    .lineLimit(1)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            accessory
            if !isDefault {
                Button(action: reset) {
                    Image(systemName: "arrow.uturn.left")
                }
                .foregroundColor(.secondary)
                .disabled(isDefault)
                Button(action: { isEnabled.toggle() }) {
                    Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isDefault ? .secondary : .blue)
                }
                .disabled(isDefault)
            }
        }.buttonStyle(.plain)
    }
#elseif os(iOS) || os(visionOS)
    package var body: some View {
        HStack {
            Text(title)
            if !isDefault {
                Button(action: reset) {
                    Image(systemName: "arrow.uturn.left")
                }
                .padding(.bottom, 3)
            } else {
                Button(action: {}) {
                    Image(systemName: "arrow.uturn.left")
                }
                .padding(.bottom, 3)
                .hidden()
                .accessibilityHidden(true)
            }
            Spacer()
            accessory
        }
    }
#else
    package var body: some View {
        Text(title)
    }
#endif
}

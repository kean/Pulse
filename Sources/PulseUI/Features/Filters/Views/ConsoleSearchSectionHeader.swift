// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct ConsoleSectionHeader: View {
    let icon: String
    let title: String
    let reset: () -> Void
    let isDefault: Bool
    @Binding var isEnabled: Bool

    init<Filter: ConsoleFilterProtocol>(
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
    }

#if os(macOS)
    var body: some View {
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
#elseif os(iOS)
    var body: some View {
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
        }
    }
#else
    var body: some View {
        Text(title)
    }
#endif
}

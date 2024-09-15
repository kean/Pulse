// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)

struct ConsoleSectionHeader: View {
    let icon: String
    let title: String
    let reset: () -> Void
    let isDefault: Bool

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
    }

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
}

#endif

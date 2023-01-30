// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI

struct InlineTabBar<T>: View where T: Hashable, T: Identifiable {
    let items: [T]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                HStack(spacing: 0) {
                    InlineTabBarItem(title: "\(item)", isSelected: selection == item) {
                        selection = item
                    }
                    if item != items.last {
                        Divider().padding(.horizontal, 6)
                    }
                }
            }
        }.fixedSize()
    }
}

struct InlineTabBarItem: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .default))
                .foregroundColor(isSelected ? .accentColor : .primary)
        }.buttonStyle(.plain)
    }
}

#endif

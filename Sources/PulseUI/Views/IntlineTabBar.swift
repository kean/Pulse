// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI

struct InlineTabBar<T>: View where T: Hashable, T: Identifiable {
    let items: [T]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                InlineTabBarItem(title: "\(item)", isSelected: selection == item) {
                    selection = item
                }
            }
        }.fixedSize()
    }
}

struct InlineTabBarItem: View {
    let title: String
    var details: String?
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            text
                .lineLimit(1)
                .padding(2)
                .padding(.horizontal, 2)
                .onHover { isHovering = $0 }
                .background(isSelected ? Color.blue.opacity(0.7) : (isHovering ? Color.blue.opacity(0.25) : nil))
                .cornerRadius(4)
        }.buttonStyle(.plain)
    }

    private var text: some View {
        var text = Text(title)
            .font(.system(size: 11, weight: .medium, design: .default))
            .foregroundColor(isSelected ? .white : .secondary)
        if let details = details, !details.isEmpty {
            text = (text + Text(" (\(details))"))
                .font(.system(size: 11, weight: .medium, design: .default))
                .foregroundColor(isSelected ? .white.opacity(0.6) : .secondary.opacity(0.6))
        }
        return text.lineLimit(1)
    }
}

#endif

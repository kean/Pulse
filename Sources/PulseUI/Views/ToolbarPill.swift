// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
package struct ToolbarPill<Content: View>: View {
    private let isActive: Bool
    private let activeColor: Color
    @ViewBuilder private let content: () -> Content

    package init(
        isActive: Bool,
        activeColor: Color = .accentColor,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isActive = isActive
        self.activeColor = activeColor
        self.content = content
    }

    package var body: some View {
        content()
            .padding(EdgeInsets(top: 8, leading: 9, bottom: 8, trailing: 8))
            .toolbarPillBackground(isActive: isActive, activeColor: activeColor)
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
extension View {
    /// Applies the standard toolbar pill background and corner clip.
    func toolbarPillBackground(isActive: Bool, activeColor: Color = .accentColor) -> some View {
        self
            #if os(watchOS) || os(tvOS)
            .background(isActive ? activeColor : Color.gray.opacity(0.2))
            #else
            .background(isActive ? activeColor : Color(.secondarySystemFill).opacity(0.8))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
extension ToolbarPill where Content == ToolbarPillLabel {
    package init(_ title: String? = nil, systemImage: String? = nil, isActive: Bool) {
        self.init(isActive: isActive) {
            ToolbarPillLabel(title: title, systemImage: systemImage, isActive: isActive)
        }
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
package struct ToolbarPillLabel: View {
    private let title: String?
    private let systemImage: String?
    private let isActive: Bool

    package init(title: String? = nil, systemImage: String? = nil, isActive: Bool) {
        self.title = title
        self.systemImage = systemImage
        self.isActive = isActive
    }

    package var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font((title == nil ? Font.footnote : Font.caption).weight(.bold))
                    .contentTransition(.symbolEffect(.replace))
            }
            if let title {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .contentTransition(.numericText())
            }
        }
        .frame(height: 18)
        .foregroundStyle(isActive ? Color.white : Color.secondary)
    }
}

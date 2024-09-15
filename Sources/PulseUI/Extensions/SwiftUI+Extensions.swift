// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Combine

#if os(iOS) || os(macOS) || os(visionOS)
extension Color {
    static var separator: Color { Color(UXColor.separator) }
    static var secondaryFill: Color { Color(UXColor.secondarySystemFill) }
}
#endif

#if os(watchOS) || os(tvOS)
extension Color {
    static var separator: Color { Color.secondary.opacity(0.3) }
    static var secondaryFill: Color { Color.secondary.opacity(0.3) }
}
#endif

extension View {
    package func invisible() -> some View {
        self.hidden().accessibilityHidden(true)
    }
}

#if os(iOS) || os(visionOS)

enum Keyboard {
    static var isHidden: AnyPublisher<Bool, Never> {
        Publishers.Merge(
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillShowNotification)
                .map { _ in false },

            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in true }
        )
        .eraseToAnyPublisher()
    }
}

#endif

// MARK: - Backport

package struct Backport<Content: View> {
    package let content: Content
}

extension View {
    package var backport: Backport<Self> { Backport(content: self) }
}

extension View {
    package func inlineNavigationTitle(_ title: String) -> some View {
        self.navigationTitle(title)
#if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

/// Allows you to use `@StateObject` only for memory management (without observing).
package final class IgnoringUpdates<T>: ObservableObject {
    package var value: T
    package init(_ value: T) { self.value = value }
}

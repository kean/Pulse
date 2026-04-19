// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

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

// MARK: - BackportButtonRole

package enum BackportButtonRole {
    case cancel
    case close
    case confirm

    package var title: String {
        switch self {
        case .cancel: "Cancel"
        case .close: "Close"
        case .confirm: "Done"
        }
    }
}

@ViewBuilder
package func makeButton(role: BackportButtonRole, title: String? = nil, action: @escaping () -> Void) -> some View {
    if #available(iOS 26, macOS 26, visionOS 26, tvOS 26, watchOS 26, *) {
        if let title {
            Button(title, role: ButtonRole(role), action: action)
        } else {
            Button(role: ButtonRole(role), action: action)
        }
    } else {
        Button(title ?? role.title, action: action)
    }
}

package struct ButtonClose: View {
    @Environment(\.dismiss) private var dismiss

    package let role: BackportButtonRole

    package init(role: BackportButtonRole = .close) {
        self.role = role
    }

    package var body: some View {
        makeButton(role: role) {
            dismiss()
        }
    }
}

@available(iOS 26, macOS 26, visionOS 26, tvOS 26, watchOS 26, *)
private extension ButtonRole {
    init(_ role: BackportButtonRole) {
        switch role {
        case .cancel: self = .cancel
        case .close: self = .close
        case .confirm: self = .confirm
        }
    }
}

/// Allows you to use `@StateObject` only for memory management (without observing).
package final class IgnoringUpdates<T>: ObservableObject {
    package var value: T
    package init(_ value: T) { self.value = value }
}

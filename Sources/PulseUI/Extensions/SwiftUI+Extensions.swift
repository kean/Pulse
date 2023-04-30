// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Combine

#if os(iOS) || os(macOS)
extension Color {
    static var separator: Color { Color(UXColor.separator) }
    static var indigo: Color { Color(UXColor.systemIndigo) }
    static var secondaryFill: Color { Color(UXColor.secondarySystemFill) }
}
#endif

#if os(watchOS) || os(tvOS)
extension Color {
    static var indigo: Color { .purple }
    static var separator: Color { Color.secondary.opacity(0.3) }
    static var secondaryFill: Color { Color.secondary.opacity(0.3) }
}
#endif

extension View {
    func invisible() -> some View {
        self.hidden().accessibilityHidden(true)
    }
}

extension ContentSizeCategory {
    var scale: CGFloat {
        switch self {
        case .extraSmall: return 0.7
        case .small: return 0.8
        case .medium: return 1.0
        case .large: return 1.0
        case .extraLarge: return 1.0
        case .extraExtraLarge: return 1.2
        case .extraExtraExtraLarge: return 1.3
        case .accessibilityMedium: return 1.4
        case .accessibilityLarge: return 1.6
        case .accessibilityExtraLarge: return 1.9
        case .accessibilityExtraExtraLarge: return 2.1
        case .accessibilityExtraExtraExtraLarge: return 2.4
        @unknown default: return 1.0
        }
    }
}

#if os(iOS)

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

struct Backport<Content: View> {
    let content: Content
}

extension View {
    var backport: Backport<Self> { Backport(content: self) }
}

extension Backport {
    @ViewBuilder
    func presentationDetents(_ detents: Set<PresentationDetent>) -> some View {
#if os(iOS)
        if #available(iOS 16, *) {
            let detents = detents.map { (detent)-> SwiftUI.PresentationDetent in
                switch detent {
                case .large: return .large
                case .medium: return .medium
                }
            }
            self.content.presentationDetents(Set(detents))
        } else {
            self.content
        }
#else
        self.content
#endif
    }

#if os(macOS)
    @ViewBuilder
    func hideListContentBackground() -> some View {
        if #available(macOS 13, *) {
            self.content.scrollContentBackground(.hidden)
        } else {
            self.content
        }
    }
#endif

    enum PresentationDetent {
        case large
        case medium
    }
}

extension View {
    func inlineNavigationTitle(_ title: String) -> some View {
        self.navigationTitle(title)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
    }

    func apply<T>(_ closure: (Self) -> T) -> T {
        closure(self)
    }
}

/// Allows you to use `@StateObject` only for memory management (without observing).
final class IgnoringUpdates<T>: ObservableObject {
    var value: T
    init(_ value: T) { self.value = value }
}

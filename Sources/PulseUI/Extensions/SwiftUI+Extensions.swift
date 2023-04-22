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

enum SwipeActionEdge {
    case leading
    case trailing

#if os(iOS) || os(macOS)
    @available(iOS 15, tvOS 15, *)
    var native: HorizontalEdge {
        switch self {
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }
#endif
}

extension Backport {
    @ViewBuilder
    func tint(_ color: Color) -> some View {
        if #available(iOS 15, tvOS 15, *) {
            content.tint(color)
        } else {
            content.foregroundColor(color)
        }
    }

    @ViewBuilder
    func swipeActions<T: View>(edge: SwipeActionEdge = .trailing, allowsFullSwipe: Bool = true, @ViewBuilder closure: () -> T) -> some View {
#if os(iOS) || os(macOS)
        if #available(iOS 15, tvOS 15, *) {
            content.swipeActions(edge: edge.native, allowsFullSwipe: allowsFullSwipe, content: closure)
        } else {
            content
        }
#else
        content
#endif
    }

    @ViewBuilder
    func searchable(text: Binding<String>) -> some View {
        if #available(iOS 15, tvOS 15, *) {
            content.searchable(text: text)
        } else {
            content
        }
    }

    @ViewBuilder
    func contextMenu<M: View, P: View>(@ViewBuilder menuItems: () -> M, @ViewBuilder preview: () -> P) -> some View {
#if !os(watchOS)
        if #available(iOS 16, tvOS 16, macOS 13, *) {
            self.content.contextMenu(menuItems: menuItems, preview: preview)
        } else {
            self.content.contextMenu(menuItems: menuItems)
        }
#else
        self.content
#endif
    }

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

    @ViewBuilder
    func monospacedDigit() -> some View {
        if #available(iOS 15, tvOS 15, *) {
            self.content.monospacedDigit()
        } else {
            self.content
        }
    }

    @ViewBuilder
    func hideListContentBackground() -> some View {
#if os(macOS)
        if #available(macOS 13, *) {
            self.content.scrollContentBackground(.hidden)
        } else {
            self.content
        }
#else
        self.content
#endif
    }

#if os(macOS)
    @ViewBuilder
    func listRowSeparators(isHidden: Bool) -> some View {
        if #available(macOS 13, *) {
            self.content.listRowSeparator(isHidden ? .hidden : .visible)
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

extension Button {
    @ViewBuilder
    static func destructive(action: @escaping () -> Void, label: () -> Label) -> some View {
        if #available(iOS 15.0, tvOS 15, *) {
            Button(role: .destructive, action: action, label: label)
        } else {
            Button(action: action, label: label)
        }
    }
}

extension View {
    func inlineNavigationTitle(_ title: String) -> some View {
        self.navigationTitle(title)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
    }

#if os(macOS)
    func showInWindow() {
        let window = NSWindow()
        window.isOpaque = false
        window.center()
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = true
        window.styleMask = window.styleMask.union([.resizable, .closable, .miniaturizable])
        window.toolbarStyle = .unified
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.titlebarAppearsTransparent = true

        window.contentViewController = NSHostingController(rootView: self)
        window.makeKeyAndOrderFront(nil)
    }
#endif

    func apply<T>(_ closure: (Self) -> T) -> T {
        closure(self)
    }
}

/// Allows you to use `@StateObject` only for memory management (without observing).
final class ObservableBag<T>: ObservableObject {
    let value: T
    init(_ value: T) { self.value = value }
}

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

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

extension NavigationLink where Label == EmptyView {
    static func programmatic(isActive: Binding<Bool>, destination: @escaping () -> Destination) -> NavigationLink {
        NavigationLink(isActive: isActive, destination: destination, label: { EmptyView() })
    }
}

struct InvisibleNavigationLinks<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack { content }
            .frame(width: 0, height: 0)
            .invisible()
    }
}

extension View {
    func invisible() -> some View {
        self.hidden()
            .backport.hideAccessibility()
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

// MARK: - Backport

struct Backport<Content: View> {
    let content: Content
}

extension View {
    var backport: Backport<Self> { Backport(content: self) }
}

extension Backport {
    enum HorizontalEdge {
        case leading, trailing

        @available(iOS 15.0, tvOS 15.0, watchOS 8.0, macOS 12.0, *)
        var edge: SwiftUI.HorizontalEdge {
            switch self {
            case .leading: return .leading
            case .trailing: return .trailing
            }
        }
    }

    @ViewBuilder
    func swipeActions<T>(edge: HorizontalEdge = .trailing, allowsFullSwipe: Bool = true, @ViewBuilder content: () -> T) -> some View where T: View {
#if os(iOS) || os(watchOS)
        if #available(iOS 15.0, watchOS 8.0, *) {
            self.content.swipeActions(edge: edge.edge, allowsFullSwipe: allowsFullSwipe, content: content)
        } else {
            self.content
        }
#else
        self.content
#endif
    }

    @ViewBuilder
    func borderedButton() -> some View {
        if #available(iOS 15.0, tvOS 14, watchOS 8.0, *) {
            self.content.buttonStyle(.bordered)
        } else {
            self.content
        }
    }

    @ViewBuilder
    func hideAccessibility() -> some View {
        if #available(iOS 14, tvOS 14, *) {
            self.content.accessibilityHidden(true)
        } else {
            self.content
        }
    }

    @ViewBuilder
    func backgroundThickMaterial(enabled: Bool = true) -> some View {
        if #available(iOS 15.0, tvOS 15.0, macOS 15.0, *) {
            if enabled {
#if !os(watchOS)
                self.content.background(.regularMaterial)
#else
                self.content
#endif
            } else {
                self.content
            }
        } else {
            self.content
        }
    }

    @ViewBuilder
    func navigationTitle(_ title: String) -> some View {
        if #available(iOS 14, tvOS 14, *) {
            self.content.navigationTitle(title)
        } else {
#if os(iOS) || os(tvOS)
            self.content.navigationBarTitle(title)
#else
            self.content.navigationTitle(title)
#endif
        }
    }

    @ViewBuilder
    func contextMenu<M: View, P: View>(@ViewBuilder menuItems: () -> M, @ViewBuilder preview: () -> P) -> some View {
#if !os(macOS) && !targetEnvironment(macCatalyst) && swift(>=5.7) && !os(watchOS)
        if #available(iOS 16.0, tvOS 16.0, macOS 13.0, *) {
            self.content.contextMenu(menuItems: menuItems, preview: preview)
        } else {
            if #available(iOS 14, tvOS 14, *) {
                self.content.contextMenu(menuItems: menuItems)
            } else {
                self.content
            }
        }
#else
        self.content
#endif
    }

    @ViewBuilder
    func presentationDetents(_ detents: Set<PresentationDetent>) -> some View {
#if os(iOS)
        if #available(iOS 16.0, *) {
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
    func fullScreenCover<Content: View>(isPresented: Binding<Bool>, @ViewBuilder _ content: @escaping () -> Content) -> some View {
#if os(iOS)
        if #available(iOS 14, *) {
            self.content.fullScreenCover(isPresented: isPresented, content: content)
        } else {
            self.content
        }
#else
        self.content
#endif
    }

#warning("TODO: this should no logner be needed")

    @ViewBuilder
    func tabBarHidden() -> some View {
#if os(iOS)
        if #available(iOS 16.0, *) {
            self.content.toolbar(.hidden, for: .tabBar)
        } else {
            self.content
        }
#else
            self.content
#endif
    }

    @ViewBuilder
    func monospacedDigit() -> some View {
        if #available(iOS 15.0, tvOS 15.0, macOS 12.0, watchOS 8.0, *) {
            self.content.monospacedDigit()
        } else {
            self.content
        }
    }

    enum PresentationDetent {
        case large
        case medium
    }
}

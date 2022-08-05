// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS)
import UIKit

struct ShareView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]?
    private let cleanup: () -> Void
    private var completion: (() -> Void)?

    init(activityItems: [Any]) {
        self.activityItems = activityItems
        self.cleanup = {}
    }

    init(_ items: ShareItems) {
        self.activityItems = items.items
        self.cleanup = items.cleanup
    }

    func onCompletion(_ completion: @escaping () -> Void) -> Self {
        var copy = self
        copy.completion = completion
        return copy
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<ShareView>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        controller.completionWithItemsHandler = { _, _, _, _ in
            cleanup()
            completion?()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ShareView>) {
    }
}

extension UIActivityViewController {
    static func show(with items: ShareItems) {
        let vc = UIActivityViewController(activityItems: items.items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in
            items.cleanup()
        }
        UIApplication.shared.topViewController?.present(vc, animated: true)
    }
}

private extension UIApplication {
    var topViewController: UIViewController?{
        let keyWindow = UIApplication.keyWindow

        if keyWindow?.rootViewController == nil{
            return keyWindow?.rootViewController
        }

        var vc = keyWindow?.rootViewController

        while vc?.presentedViewController != nil {
            switch vc?.presentedViewController {
            case let navagationController as UINavigationController:
                vc = navagationController.viewControllers.last
            case let tabBarController as UITabBarController:
                vc = tabBarController.selectedViewController
            default:
                vc = vc?.presentedViewController
            }
        }
        return vc
    }
}

struct ShareButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "square.and.arrow.up")
        }
    }
}
#endif

#if os(macOS)
import AppKit

struct ShareView: View {
    let items: ShareItems

    private var cleanup: (() -> Void)?
    private var completion: (() -> Void)?

    init(_ items: ShareItems) {
        self.items = items
        self.cleanup = items.cleanup
    }

    func onCompletion(_ completion: @escaping () -> Void) -> Self {
        var copy = self
        copy.completion = completion
        return copy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(NSSharingService.sharingServices(forItems: items.items), id: \.title) { item in
                Button(action: { item.perform(withItems: items.items) }) {
                    HStack {
                        Image(nsImage: item.image)
                        Text(item.title)
                    }
                }.buttonStyle(.plain)
            }
        }.padding(8)
    }
}

#endif

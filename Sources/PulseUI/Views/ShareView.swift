// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS)

import UIKit

@available(iOS 13.0, *)
struct ShareView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]?
    private let cleanup: () -> Void

    // TODO: remove this variant
    init(activityItems: [Any]) {
        self.activityItems = activityItems
        self.cleanup = {}
    }

    init(_ items: ShareItems) {
        self.activityItems = items.items
        self.cleanup = items.cleanup
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<ShareView>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        controller.completionWithItemsHandler = { _, _, _, _ in
            cleanup()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ShareView>) {
    }
}

@available(iOS 13.0, *)
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

@available(iOS 13.0, *)
struct ShareButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "square.and.arrow.up")
        }
    }
}
#endif

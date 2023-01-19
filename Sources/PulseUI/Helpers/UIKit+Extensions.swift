// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import UIKit
import SwiftUI

extension UIView {
    func pinToSuperview(insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: superview!.topAnchor, constant: insets.top),
            trailingAnchor.constraint(equalTo: superview!.trailingAnchor, constant: -insets.right),
            leadingAnchor.constraint(equalTo: superview!.leadingAnchor, constant: insets.left),
            bottomAnchor.constraint(equalTo: superview!.bottomAnchor, constant: -insets.bottom)
        ])
    }
}

extension UIViewController {
    @discardableResult
    static func present<ContentView: View>(_ closure: (_ dismiss: @escaping () -> Void) -> ContentView) -> UIViewController? {
        present { UIHostingController(rootView: closure($0)) }
    }

    @discardableResult
    static func present(_ closure: (_ dismiss: @escaping () -> Void) -> UIViewController) -> UIViewController? {
        guard let keyWindow = UIApplication.shared.windows.filter({ $0.isKeyWindow }).first,
              var topController = keyWindow.rootViewController else {
            return nil
        }
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        let vc = closure({ [weak topController] in
            topController?.dismiss(animated: true, completion: nil)
        })
        topController.present(vc, animated: true, completion: nil)
        return vc
    }
}

extension UIApplication {
    static var keyWindow: UIWindow? {
        shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

#endif

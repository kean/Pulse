// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import UIKit
import SwiftUI

#if os(iOS)
public extension UIView {
    static func vStack(
        alignment: UIStackView.Alignment = .fill,
        distribution: UIStackView.Distribution = .fill,
        spacing: CGFloat = 0,
        margins: UIEdgeInsets? = nil,
        _ views: [UIView]
    ) -> UIStackView {
        makeStackView(axis: .vertical, alignment: alignment, distribution: distribution, spacing: spacing, margins: margins, views)
    }

    static func hStack(
        alignment: UIStackView.Alignment = .fill,
        distribution: UIStackView.Distribution = .fill,
        spacing: CGFloat = 0,
        margins: UIEdgeInsets? = nil,
        _ views: [UIView]
    ) -> UIStackView {
        makeStackView(axis: .horizontal, alignment: alignment, distribution: distribution, spacing: spacing, margins: margins, views)
    }
}

private extension UIView {
    static func makeStackView(axis: NSLayoutConstraint.Axis, alignment: UIStackView.Alignment, distribution: UIStackView.Distribution, spacing: CGFloat, margins: UIEdgeInsets?, _ views: [UIView]) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = axis
        stack.alignment = alignment
        stack.distribution = distribution
        stack.spacing = spacing
        if let margins = margins {
            stack.isLayoutMarginsRelativeArrangement = true
            stack.layoutMargins = margins
        }
        return stack
    }
}

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

@available(iOS 13.0, *)
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
#endif

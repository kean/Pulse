// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import UIKit

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

extension UIApplication {
    static var keyWindow: UIWindow? {
        shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

#endif

// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import Foundation
import UIKit
import PulseCore
import SwiftUI

public final class MainViewController: UITabBarController {
    private let model: Any?

    public init(store: LoggerStore = .default) {
        if #available(iOS 13.0, *) {
            self.model = MainViewModel(store: store, onDismiss: nil)
        } else {
            self.model = nil
        }
        super.init(nibName: nil, bundle: nil)
    }

    required convenience init?(coder: NSCoder) {
        self.init()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 13.0, *) {
            addConsoleView()
        } else {
            addPlaceholderView()
        }
    }

    @available(iOS 13, *)
    private func addConsoleView() {
        guard let model = model as? MainViewModel else {
            return addPlaceholderView()
        }
        viewControllers = model.items.enumerated().map {
            let item = $0.element
            let vc = UIHostingController(rootView: model.makeView(for: item))
            vc.tabBarItem = UITabBarItem(title: item.title, image: UIImage(systemName: item.imageName), tag: $0.offset)
            return vc
        }
    }

    private func addPlaceholderView() {
        let stack = UIStackView(arrangedSubviews: [])
        stack.alignment = .center
        stack.spacing = 12
        stack.axis = .vertical

        let label = UILabel()
        label.text = "Console is only available\non iOS 13 and higher"
        label.textColor = UIColor.black
        label.textAlignment = .center
        label.numberOfLines = 0
        stack.addArrangedSubview(label)

        if navigationController != nil || presentingViewController != nil {
            let buttonClose = UIButton(type: .system)
            buttonClose.setTitle("Close", for: .normal)
            buttonClose.addTarget(self, action: #selector(buttonCloseTapped), for: .touchUpInside)
            stack.addArrangedSubview(buttonClose)
        }

        view.backgroundColor = UIColor(red: 230.0/255.0, green: 230.0/255.0, blue: 230.0/255.0, alpha: 1.0)
        view.addSubview(stack)

        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 1),
            stack.trailingAnchor.constraint(lessThanOrEqualToSystemSpacingAfter: view.safeAreaLayoutGuide.trailingAnchor, multiplier: 1),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func buttonCloseTapped() {
        if let navigationController = self.navigationController {
            navigationController.popViewController(animated: true)
        } else if let presentingViewController = self.presentingViewController {
            presentingViewController.dismiss(animated: true, completion: nil)
        }
    }
}

#endif

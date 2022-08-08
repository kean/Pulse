// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import Foundation
import UIKit
import Pulse
import SwiftUI

public final class MainViewController: UITabBarController {
    private let viewModel: MainViewModel

    public static var isAutomaticAppearanceOverrideRemovalEnabled = true

    public init(store: LoggerStore = .shared, onDismiss: (() -> Void)? = nil) {
        self.viewModel = MainViewModel(store: store, onDismiss: onDismiss)
        super.init(nibName: nil, bundle: nil)

        if MainViewController.isAutomaticAppearanceOverrideRemovalEnabled {
            removeAppearanceOverrides()
        }
    }

    required convenience init?(coder: NSCoder) {
        self.init()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        viewControllers = viewModel.items.enumerated().map {
            let item = $0.element
            let vc = UINavigationController(rootViewController: UIHostingController(rootView: viewModel.makeView(for: item)))
            vc.tabBarItem = UITabBarItem(title: item.title, image: UIImage(systemName: item.imageName), tag: $0.offset)
            return vc
        }
    }
}

private var isAppearanceCleanupNeeded = true

private func removeAppearanceOverrides() {
    guard isAppearanceCleanupNeeded else { return }
    isAppearanceCleanupNeeded = false

    let appearance = UINavigationBar.appearance(whenContainedInInstancesOf: [MainViewController.self])
    appearance.tintColor = nil
    appearance.barTintColor = nil
    appearance.titleTextAttributes = nil
    appearance.isTranslucent = true
}

#endif

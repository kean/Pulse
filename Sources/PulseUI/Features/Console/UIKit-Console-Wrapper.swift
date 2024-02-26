//
//  UIKit-Console-Wrapper.swift
//
//
//  Created by Morris Richman on 2/25/24.
//

import UIKit
import SwiftUI
import CoreData
import Pulse
import Combine


/// Initializes the console view controller
///
/// - parameters:
///   - store: The store to display. By default, `LoggerStore/shared`.
///   - mode: The console mode. By default, ``ConsoleMode/all``. If you change
///   the mode to ``ConsoleMode/network``, the console will only display the
public func UIConsoleViewController(store: LoggerStore = .shared, mode: ConsoleMode = .all) -> UIHostingController<ConsoleView> {
    UIHostingController(rootView: ConsoleView(store: store, mode: mode))
}

extension UIHostingController<ConsoleView> {
    public func closeButtonHidden(_ isHidden: Bool = true) {
        self.rootView = self.rootView.closeButtonHidden(isHidden)
    }
}

@available(iOS 16.0, *)
/// Initializes the console view controller with swiftui navigation built in
///
/// - parameters:
///   - store: The store to display. By default, `LoggerStore/shared`.
///   - mode: The console mode. By default, ``ConsoleMode/all``. If you change
///   the mode to ``ConsoleMode/network``, the console will only display the
public func UIConsoleNavigationViewController(store: LoggerStore = .shared, mode: ConsoleMode = .all) -> UIHostingController<NavigationStack<NavigationPath, ConsoleView>> {
    
    let view = NavigationStack {
        ConsoleView(store: store, mode: mode)
    }
    
    return UIHostingController(rootView: view)
}

/// Initializes the console view controller with swiftui navigation built in
///
/// - parameters:
///   - store: The store to display. By default, `LoggerStore/shared`.
///   - mode: The console mode. By default, ``ConsoleMode/all``. If you change
///   the mode to ``ConsoleMode/network``, the console will only display the
public func UIConsoleNavigationViewController(store: LoggerStore = .shared, mode: ConsoleMode = .all) -> UIHostingController<NavigationView<ConsoleView>> {
    
    let view = NavigationView {
        ConsoleView(store: store, mode: mode)
    }
    
    return UIHostingController(rootView: view)
}

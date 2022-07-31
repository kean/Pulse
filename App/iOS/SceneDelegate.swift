// The MIT License (MIT)
//
// Copyright (c) 2020-2022 Alexander Grebenyuk (github.com/kean).

import UIKit
import SwiftUI
import CoreData
import PulseUI
import PulseCore

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = DocumentBrowserViewController()
            self.window = window
            window.makeKeyAndVisible()
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let context = URLContexts.first else {
            return
        }

        do {
            guard context.url.startAccessingSecurityScopedResource() else {
                throw NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL, userInfo: [NSLocalizedDescriptionKey: "Failed to get access to file"])
            }

            let store = try LoggerStore(storeURL: context.url)
            let vc = UIHostingController(rootView: MainView(store: store, onDismiss: { [weak self] in
                self?.window?.rootViewController?.dismiss(animated: true, completion: nil)
            }))
            vc.modalPresentationStyle = .fullScreen
            vc.onDeinit {
                context.url.stopAccessingSecurityScopedResource()
            }
            window?.rootViewController?.present(vc, animated: true, completion: nil)
        } catch {
            let vc = UIAlertController(title: "Failed to open store", message: error.localizedDescription, preferredStyle: .alert)
            vc.addAction(.init(title: "Ok", style: .cancel, handler: nil))
            window?.rootViewController?.present(vc, animated: true, completion: nil)
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
}

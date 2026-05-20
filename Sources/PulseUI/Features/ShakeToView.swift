// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import UIKit
import SwiftUI

#if os(iOS)

extension UIViewController {
    
    open override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        
        if #available(iOS 16.0, *),
           motion == .motionShake,
           UserDefaults.standard.bool(forKey: ConsoleView.shakeToPresentIsEnableKey) {
            
            let logVC = UIHostingController(rootView: NavigationStack { ConsoleView() })
            present(logVC, animated: true, completion: nil)
        }
        
        next?.motionBegan(motion, with: event)
    }
}

extension ConsoleView {
    static let shakeToPresentIsEnableKey = "pulse-shake-to-present-is-enabled"
    
    public static func shakeToPresent(isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: shakeToPresentIsEnableKey)
    }
}

#endif

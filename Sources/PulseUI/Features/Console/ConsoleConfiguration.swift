// The MIT License (MIT)
//
//  Created by A.J. van der Lee on 01/07/2024.
//  Copyright © 2024 kean. All rights reserved.
//

import Foundation

/// Defines UI configurations to enable/disable elements or change behavior.
public struct ConsoleConfiguration {
    public static let `default` = ConsoleConfiguration()
    
    let shareStoreOutputs: [ShareStoreOutput]
    
    /// Creates a new `ConsoleConfiguration`
    /// - Parameter shareStoreOutputs: The available store share outputs. Defaults to `allCases`.
    public init(shareStoreOutputs: [ShareStoreOutput] = ShareStoreOutput.allCases) {
        self.shareStoreOutputs = shareStoreOutputs
    }
}

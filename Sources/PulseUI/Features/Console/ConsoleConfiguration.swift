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
    let allowRemoteLogging: Bool
    
    /// Creates a new `ConsoleConfiguration`
    /// - Parameter shareStoreOutputs: The available store share outputs. Defaults to `allCases`.
    /// - Parameter allowRemoteLogging: Enable/disable the remote logging option.
    public init(
        shareStoreOutputs: [ShareStoreOutput] = ShareStoreOutput.allCases,
        allowRemoteLogging: Bool = true
    ) {
        self.shareStoreOutputs = shareStoreOutputs
        self.allowRemoteLogging = allowRemoteLogging
    }
}

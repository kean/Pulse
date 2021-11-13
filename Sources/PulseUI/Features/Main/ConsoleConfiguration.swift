// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import Foundation

public struct ConsoleConfiguration {
    public var isStoreSharingEnabled: Bool
    
    public static let `default` = ConsoleConfiguration()
    
    public init(isStoreSharingEnabled: Bool = true) {
        self.isStoreSharingEnabled = isStoreSharingEnabled
    }
}

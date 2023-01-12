// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData

struct ConsoleNetworkSearchCriteria: Hashable {


    static let `default` = ConsoleNetworkSearchCriteria()

    var isDefault: Bool {
        self == ConsoleNetworkSearchCriteria.default
    }

}

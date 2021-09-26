
//  Created by Alexander Grebenyuk on 29.03.2021.

import Foundation
import PulseCore

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
struct AppContext {
    let store: LoggerStore
    var share: ConsoleShareService { .init(store: store )}
}

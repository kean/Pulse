// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

struct NetworkInspectorViewModel {
    let task: NetworkTaskEntity

    var title: String {
        task.url.flatMap(URL.init(string:))?.lastPathComponent ?? "Request"
    }

    var pinViewModel: PinButtonViewModel? {
        PinButtonViewModel(task)
    }

    func shareTaskAsHTML() -> URL? {
        ShareService.share(task, as: .html).items.first as? URL
    }
}

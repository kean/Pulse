// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Cocoa
import Pulse
import SwiftUI
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // Remote logging
    @AppStorage("remote_logging-custom-port") var port: String = ""
    @AppStorage("remote_logging-custom-name") var serviceName: String = ""
}

// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

// Shortcut, should've been some sort of a ViewModel, but not sure how to do that
// given the current SwiftUI navigation state
@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
struct ConsoleMessageDetailsRouter: View {
    let context: AppContext
    let message: LoggerMessageEntity

    var body: some View {
        if let request = message.request {
            NetworkInspectorView(model: .init(message: message, request: request, context: context))
        } else {
            ConsoleMessageDetailsView(model: .init(context: context, message: message))
        }
    }
}

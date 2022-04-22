// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore

#if os(iOS) || os(tvOS) || os(watchOS)
@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
struct ConsoleMessageDetailsRouter: View {
    let context: AppContext
    @Binding var entity: NSManagedObject?

    var body: some View {
        if let message = entity as? LoggerMessageEntity {
            if let request = message.request {
                NetworkInspectorView(viewModel: .init(request: request, context: context))
            } else {
                ConsoleMessageDetailsView(viewModel: .init(context: context, message: message))
            }
        } else if let request = entity as? LoggerNetworkRequestEntity {
            NetworkInspectorView(viewModel: .init(request: request, context: context))
        }
    }
}
#endif

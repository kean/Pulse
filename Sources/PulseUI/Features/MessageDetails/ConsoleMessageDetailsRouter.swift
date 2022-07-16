// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore

#if os(iOS) || os(tvOS) || os(watchOS)
struct ConsoleMessageDetailsRouter: View {
    let store: LoggerStore
    @Binding var entity: NSManagedObject?

    var body: some View {
        if let message = entity as? LoggerMessageEntity {
            if let request = message.request {
                NetworkInspectorView(viewModel: .init(request: request, store: store))
            } else {
                ConsoleMessageDetailsView(viewModel: .init(store: store, message: message))
            }
        } else if let request = entity as? LoggerNetworkRequestEntity {
            NetworkInspectorView(viewModel: .init(request: request, store: store))
        }
    }
}
#endif

//
//// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
struct PinButton: View {
    let model: PinButtonViewModel
    var isTextNeeded: Bool = true

    @State private var isPinned = false

    var body: some View {
        Button(action: model.togglePin) {
            if isTextNeeded {
                Text(isPinned ? "Remove Pin" : "Pin")
            }
            Image(systemName: isPinned ? "pin.slash" : "pin")
        }.onReceive(model.isPinnedPublisher) {
            self.isPinned = $0
        }
    }
}

@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
struct PinButtonViewModel {
    private let objectID: NSManagedObjectID
    private let service: PinService

    init(service: PinService, objectID: NSManagedObjectID) {
        self.service = service
        self.objectID = objectID
    }

    var isPinnedPublisher: AnyPublisher<Bool, Never> {
        service.isPinnedMessageWithID(objectID)
    }

    func togglePin() {
        service.togglePinWithID(objectID)
    }
}

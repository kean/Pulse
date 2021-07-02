// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import Foundation
import PulseCore
import CoreData
import Combine

@available(iOS 13.0, tvOS 13, watchOS 6, *)
final class PinService: ObservableObject  {
    @Published var pins = Set<NSManagedObjectID>()

    static var services = [ObjectIdentifier: PinService]()

    static func service(forStore store: LoggerStore) -> PinService {
        if let service = services[ObjectIdentifier(store)] {
            return service
        }
        let service = PinService()
        services[ObjectIdentifier(store)] = service
        return service
    }

    func pinMessageWithID(_ id: NSManagedObjectID) {
        var pins = self.pins
        pins.insert(id)
        self.pins = pins
    }

    func removeMessageWithID(_ id: NSManagedObjectID) {
        var pins = self.pins
        pins.remove(id)
        self.pins = pins
    }

    func togglePinWithID(_ id: NSManagedObjectID) {
        if pins.remove(id) == nil {
            pins.insert(id)
        }
    }

    func removeAll() {
        pins = []
    }

    func isPinnedMessageWithID(_ id: NSManagedObjectID) -> AnyPublisher<Bool, Never> {
        $pins
            .map { set -> Bool in set.contains(id) }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData
import Combine
import Pulse

/// Keeps track of hosts, paths, etc.
final class LoggerStoreIndex {
    var hosts: Set<String> = []

    private let store: LoggerStore
    private var cancellable: AnyCancellable?

    init(store: LoggerStore) {
        self.store = store

        store.backgroundContext.perform {
            self.populate()
        }
        cancellable = store.events.subscribe(on: DispatchQueue.main).sink { [weak self] in
            self?.handle($0)
        }
    }

    private func handle(_ event: LoggerStore.Event) {
        switch event {
        case .networkTaskCompleted(let event):
            if let host = event.originalRequest.url.flatMap(getHost) {
                var hosts = self.hosts
                let (isInserted, _) = hosts.insert(host)
                if isInserted { self.hosts = hosts }
            }
        default:
            break
        }
    }

    private func populate() {
        // These calls are fast enough (1-2ms for 5000 messages) so we
        // could avoid storing this persistently.
        let hosts: Set<String> = {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "NetworkTaskEntity")
            request.resultType = .dictionaryResultType
            request.returnsDistinctResults = true
            request.propertiesToFetch = ["host"]
            guard let results = try? store.backgroundContext.fetch(request) as? [[String: String]] else {
                return []
            }
            return Set(results.flatMap { $0.values })
        }()

        DispatchQueue.main.async {
            self.hosts = hosts
        }
    }
}

private func getHost(for url: URL) -> String? {
    if let host = url.host {
        return host
    }
    if url.scheme == nil, let url = URL(string: "https://" + url.absoluteString) {
        return url.host ?? "" // URL(string: "example.com")?.host with not scheme returns host: ""
    }
    return nil
}

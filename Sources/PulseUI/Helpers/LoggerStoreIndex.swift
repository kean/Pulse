// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData
import Combine
import Pulse

/// Keeps track of hosts, paths, etc.
package final class LoggerStoreIndex: ObservableObject {
    @Published private(set) package var labels: Set<String> = []
    @Published private(set) package var files: Set<String> = []
    @Published private(set) package var hosts: Set<String> = []
    @Published private(set) package var paths: Set<String> = []

    private let context: NSManagedObjectContext
    private var cancellable: AnyCancellable?

    convenience package init(store: LoggerStore) {
        self.init(context: store.backgroundContext)

        store.backgroundContext.perform {
            self.prepopulate()
        }
        cancellable = store.events.receive(on: DispatchQueue.main).sink { [weak self] in
            self?.handle($0)
        }
    }

    package init(context: NSManagedObjectContext) {
        self.context = context
        context.perform {
            self.prepopulate()
        }
    }

    private func handle(_ event: LoggerStore.Event) {
        switch event {
        case .messageStored(let event):
            self.files.insert(event.file)
            self.labels.insert(event.label)
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

    private func prepopulate() {
        let files = context.getDistinctValues(entityName: "LoggerMessageEntity", property: "file")
        let labels = context.getDistinctValues(entityName: "LoggerMessageEntity", property: "label")
        let urls = context.getDistinctValues(entityName: "NetworkTaskEntity", property: "url")

        var hosts = Set<String>()
        var paths = Set<String>()

        for url in urls {
            guard let components = URLComponents(string: url) else {
                continue
            }
            if let host = components.host, !host.isEmpty {
                hosts.insert(host)
            }
            paths.insert(components.path)
        }

        DispatchQueue.main.async {
            self.labels = labels
            self.files = files
            self.hosts = hosts
            self.paths = paths
        }
    }

    func clear() {
        self.labels = []
        self.files = []
        self.paths = []
        self.hosts = []
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

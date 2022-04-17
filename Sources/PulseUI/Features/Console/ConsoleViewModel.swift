// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import CoreData
import PulseCore
import Combine
import SwiftUI

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
final class ConsoleViewModel: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
    let configuration: ConsoleConfiguration

    @Published private(set) var messages: [LoggerMessageEntity]

    // Search criteria
    let searchCriteria: ConsoleSearchCriteriaViewModel
    @Published var filterTerm: String = ""
    @Published private(set) var quickFilters: [QuickFilterViewModel] = []

    // Apple Watch file transfers
#if os(watchOS) || os(iOS)
    @Published private(set) var fileTransferStatus: FileTransferStatus = .initial
    @Published var fileTransferError: FileTransferError?
#endif

    var onDismiss: (() -> Void)?

    // TODO: get DI right, this is a quick workaround to fix @EnvironmentObject crashes
    var context: AppContext { .init(store: store) }

    private let store: LoggerStore
    private let contentType: ConsoleContentType
    private let controller: NSFetchedResultsController<LoggerMessageEntity>
    private var latestSessionId: String?
    private var cancellables = [AnyCancellable]()

    init(store: LoggerStore, configuration: ConsoleConfiguration = .default, contentType: ConsoleContentType = .all) {
        self.store = store
        self.configuration = configuration
        self.contentType = contentType

        let request = NSFetchRequest<LoggerMessageEntity>(entityName: "\(LoggerMessageEntity.self)")
        request.fetchBatchSize = 250
        request.relationshipKeyPathsForPrefetching = ["request"]
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LoggerMessageEntity.createdAt, ascending: false)]

        self.controller = NSFetchedResultsController<LoggerMessageEntity>(fetchRequest: request, managedObjectContext: store.container.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        self.messages = []

        self.searchCriteria = ConsoleSearchCriteriaViewModel(isDefaultStore: store === LoggerStore.default)

        super.init()

        controller.delegate = self

        $filterTerm.throttle(for: 0.33, scheduler: RunLoop.main, latest: true).dropFirst().sink { [weak self] filterTerm in
            self?.refresh(filterTerm: filterTerm)
        }.store(in: &cancellables)

        searchCriteria.dataNeedsReload.throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true).sink { [weak self] in
            self?.refreshNow()
        }.store(in: &cancellables)

        refreshNow()

#if os(watchOS) || os(iOS)
        LoggerSyncSession.shared.$fileTransferStatus.sink(receiveValue: { [weak self] in
            self?.fileTransferStatus = $0
            if case let .failure(error) = $0 {
                self?.fileTransferError = FileTransferError(message: error.localizedDescription)
            }
        }).store(in: &cancellables)
#endif
    }

    // MARK: Refresh

    private func refreshNow() {
        refresh(filterTerm: filterTerm)
    }

    private func refresh(filterTerm: String) {
        // Reset quick filters
        refreshQuickFilters(criteria: searchCriteria.criteria)

        // Get sessionId
        if latestSessionId == nil {
            latestSessionId = messages.first?.session
        }
        let sessionId = store === LoggerStore.default ? LoggerSession.current.id.uuidString : latestSessionId

        // Search messages
        ConsoleSearchCriteria.update(request: controller.fetchRequest, contentType: contentType, filterTerm: filterTerm, criteria: searchCriteria.criteria, filters: searchCriteria.filters, sessionId: sessionId, isOnlyErrors: false)
        try? controller.performFetch()

        self.messages = controller.fetchedObjects ?? []
    }

    // MARK: Pins

    func removeAllPins() {
        store.removeAllPins()
    }

    private func refreshQuickFilters(criteria: ConsoleSearchCriteria) {
        quickFilters = searchCriteria.makeQuickFilters()
    }

    func share(as output: ShareStoreOutput) -> ShareItems {
#if os(iOS)
        return ShareItems(store: store, output: output)
#else
        return ShareItems(messages: store)
#endif
    }

    func buttonRemoveAllMessagesTapped() {
        store.removeAll()

#if os(iOS)
        runHapticFeedback(.success)
        ToastView {
            HStack {
                Image(systemName: "trash")
                Text("All messages removed")
            }
        }.show()
#endif
    }

#if os(watchOS) || os(iOS)
    @available(watchOS 7.0, *)
    func tranferStore() {
        LoggerSyncSession.shared.transfer(store: store)
    }
#endif

    // MARK: - NSFetchedResultsControllerDelegate

    // This never gets called on macOS
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.messages = self.controller.fetchedObjects ?? []
    }
}

enum ConsoleContentType {
    case all
    case network
    case pins
}

struct ConsoleMatch {
    let index: Int
    let objectID: NSManagedObjectID
}

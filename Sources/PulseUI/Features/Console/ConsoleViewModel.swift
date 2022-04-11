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
    let searchCriteria = ConsoleSearchCriteriaViewModel()
    @Published var filterTerm: String = ""
    @Published private(set) var quickFilters: [QuickFilterViewModel] = []

    // Apple Watch file transfers
    #if os(watchOS) || os(iOS)
    @Published private(set) var fileTransferStatus: FileTransferStatus = .initial
    @Published var fileTransferError: FileTransferError?
    #endif
    
    #if os(iOS) || os(tvOS) || os(watchOS)
    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, *)
    var remoteLoggerViewModel: RemoteLoggerSettingsViewModel? {
        _remoteLoggerViewModel as? RemoteLoggerSettingsViewModel
    }
    private var _remoteLoggerViewModel: Any!
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
        
        #if os(iOS) || os(tvOS) || os(watchOS)
        if #available(iOS 14.0, *) {
            if store === RemoteLogger.shared.store {
                _remoteLoggerViewModel = RemoteLoggerSettingsViewModel()
            }
        }
        #endif

        super.init()

        if store !== LoggerStore.default {
            searchCriteria.criteria.dates.isCurrentSessionOnly = false
        }

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
        #warning("TODO: [P01] Pass filters")
        ConsoleSearchCriteria.update(request: controller.fetchRequest, contentType: contentType, filterTerm: filterTerm, criteria: searchCriteria.criteria, filters: [], sessionId: sessionId, isOnlyErrors: false)
        try? controller.performFetch()

        self.messages = controller.fetchedObjects ?? []
    }

    // MARK: Pins
    
    func removeAllPins() {
        store.removeAllPins()
    }

    // MARK: Quick Filters

    private func makeQuickFilters(criteria: ConsoleSearchCriteria) -> [QuickFilterViewModel] {
        var filters = [QuickFilterViewModel]()
        func addResetIfNeeded() {
            #warning("TODO: [P01] Fix for non-current stores")
            if !criteria.isDefault {
                filters.append(QuickFilterViewModel(title: "Reset", color: .secondary, imageName: "arrow.clockwise" ) { [weak self] in
                    self?.searchCriteria.resetAll()
                })
            }
        }
        #if os(watchOS)
        addResetIfNeeded()
        #endif
        if !criteria.logLevels.isEnabled || criteria.logLevels.levels != [.error, .critical] {
            filters.append(QuickFilterViewModel(title: "Errors", color: .secondary, imageName: "exclamationmark.octagon") { [weak self] in
                self?.searchCriteria.criteria.logLevels.isEnabled = true
                self?.searchCriteria.criteria.logLevels.levels = [.error, .critical]
            })
        }
        #warning("TODO: [P01] Rework how these filters are implemented on watchOS")
        #if os(watchOS)
        if !criteria.onlyPins {
            filters.append(QuickFilterViewModel(title: "Pins", color: .secondary, imageName: "pin") { [weak self] in
                self?.searchCriteria.criteria.onlyPins = true
            })
        }
        if !criteria.onlyNetwork {
            filters.append(QuickFilterViewModel(title: "Networking", color: .secondary, imageName: "cloud") { [weak self] in
                self?.searchCriteria.criteria.onlyNetwork = true
            })
        }
        #endif
        #warning("TODO: [P01] This is incorrect + we need better filters")
        if !criteria.dates.isEnabled ||
            ((criteria.dates.startDate == nil || !criteria.dates.isStartDateEnabled) &&
            (criteria.dates.endDate == nil || !criteria.dates.isEndDateEnabled)) {
            filters.append(QuickFilterViewModel(title: "Today", color: .secondary, imageName: "arrow.clockwise") { [weak self] in
                let calendar = Calendar.current
                let startDate = calendar.startOfDay(for: Date())
                self?.searchCriteria.criteria.dates = .make(startDate: startDate, endDate: startDate + 86400)
            })
            filters.append(QuickFilterViewModel(title: "Recent", color: .secondary, imageName: "arrow.clockwise") { [weak self] in
                self?.searchCriteria.criteria.dates = .make(startDate: Date() - 1200, endDate: nil)
            })
        }
        #if os(iOS)
        addResetIfNeeded()
        #endif
        return filters
    }

    private func refreshQuickFilters(criteria: ConsoleSearchCriteria) {
        quickFilters = makeQuickFilters(criteria: criteria)
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

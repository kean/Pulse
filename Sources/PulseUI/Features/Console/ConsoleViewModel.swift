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
    
    @Published private(set) var messages: [LoggerMessageEntity] {
        didSet {
            #if os(macOS)
            textSearch.replace(messages)
            #endif
        }
    }

    #if os(macOS)
    let list: NotListViewModel<LoggerMessageEntity>
    let details: ConsoleDetailsRouterViewModel
    @Published private(set) var allLabels: [String] = []
    #endif

    // Search criteria
    @Published var filterTerm: String = ""
    @Published var searchCriteria: ConsoleSearchCriteria = .init()
    @Published private(set) var quickFilters: [QuickFilterViewModel] = []

    // Text search (not the same as filter)
    #if os(macOS)
    @Published var searchTerm: String = ""
    @Published var searchOptions = StringSearchOptions()
    @Published private(set) var selectedMatchIndex = 0
    @Published private(set) var matches: [ConsoleMatch] = []

    private var matchesSet: Set<NSManagedObjectID> = []
    private let textSearch = ManagedObjectTextSearch<LoggerMessageEntity> { $0.text }
    #endif

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

        #if os(macOS)
        self.list = NotListViewModel()
        self.details = ConsoleDetailsRouterViewModel(context: .init(store: store))
        #endif
        
        #if os(iOS) || os(tvOS) || os(watchOS)
        if #available(iOS 14.0, *) {
            if store === RemoteLogger.shared.store {
                _remoteLoggerViewModel = RemoteLoggerSettingsViewModel()
            }
        }
        #endif

        super.init()

        if store !== LoggerStore.default {
            searchCriteria.dates.isCurrentSessionOnly = false
        }

        controller.delegate = self

        Publishers.CombineLatest($filterTerm.throttle(for: 0.33, scheduler: RunLoop.main, latest: true), $searchCriteria).dropFirst().sink { [unowned self] filterTerm, criteria in
            self.refresh(filterTerm: filterTerm, criteria: criteria)
        }.store(in: &cancellables)

        refresh(filterTerm: filterTerm, criteria: searchCriteria)

        #if os(macOS)
        Publishers.CombineLatest($searchTerm.throttle(for: 0.33, scheduler: RunLoop.main, latest: true), $searchOptions).dropFirst().sink { [unowned self] searchTerm, searchOptions in
            self.refresh(searchTerm: searchTerm, searchOptions: searchOptions)
        }.store(in: &cancellables)

        store.backgroundContext.perform {
            self.getAllLabels()
        }
        #endif

        #if os(watchOS) || os(iOS)
        LoggerSyncSession.shared.$fileTransferStatus.sink(receiveValue: { [weak self] in
            self?.fileTransferStatus = $0
            if case let .failure(error) = $0 {
                self?.fileTransferError = FileTransferError(message: error.localizedDescription)
            }
        }).store(in: &cancellables)
        #endif
    }

    #if os(macOS)
    private func getAllLabels() {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "\(LoggerMessageEntity.self)")

        // Required! Unless you set the resultType to NSDictionaryResultType, distinct can't work.
        // All objects in the backing store are implicitly distinct, but two dictionaries can be duplicates.
        // Since you only want distinct names, only ask for the 'name' property.
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = ["label"]
        fetchRequest.returnsDistinctResults = true

        // Now it should yield an NSArray of distinct values in dictionaries.
        let map = (try? store.backgroundContext.fetch(fetchRequest)) ?? []
        let values = (map as? [[String: String]])?.compactMap { $0["label"] }

        DispatchQueue.main.async {
            self.allLabels = values?.sorted() ?? []
        }
    }

    func scrollTo(_ message: LoggerMessageEntity) {
        doneSearch()
        searchCriteria = .default

        if let index = messages.firstIndex(where: { $0.objectID == message.objectID }) {
            list.scrollToIndex = index
            details.selectedEntity = messages[index]
        }
    }
    #endif

    // MARK: Refresh

    private func refresh(filterTerm: String, criteria: ConsoleSearchCriteria) {
        // Reset quick filters
        refreshQuickFilters(criteria: criteria)

        // Get sessionId
        if latestSessionId == nil {
            latestSessionId = messages.first?.session
        }
        let sessionId = store === LoggerStore.default ? LoggerSession.current.id.uuidString : latestSessionId

        // Search messages
        #warning("TODO: [P01] Pass filters")
        ConsoleSearchCriteria.update(request: controller.fetchRequest, contentType: contentType, filterTerm: filterTerm, criteria: criteria, filters: [], sessionId: sessionId, isOnlyErrors: false)
        try? controller.performFetch()

        self.messages = controller.fetchedObjects ?? []

        #if os(macOS)
        self.list.elements = self.messages
        self.refresh(searchTerm: searchTerm, searchOptions: searchOptions)
        #endif
    }

    // MARK: Pins
    
    func removeAllPins() {
        store.removeAllPins()
    }
    
    #if os(macOS)
    private func refresh(searchTerm: String, searchOptions: StringSearchOptions) {
        if messages.count > 0, searchTerm.count > 1 {
            let previousMatchObjectID = !matches.isEmpty ? matches[selectedMatchIndex].objectID : nil
            matches = textSearch.search(term: searchTerm, options: searchOptions)
            matchesSet = Set(matches.map { $0.objectID })
            if previousMatchObjectID == nil || !matchesSet.contains(previousMatchObjectID!) {
               updateMatchIndex(0)
            } else {
                if let newIndexOfPreviousMatch = matches.firstIndex(where: { $0.objectID == previousMatchObjectID }) {
                    selectedMatchIndex = newIndexOfPreviousMatch
                }
            }
        } else {
            selectedMatchIndex = 0
            matches = []
            matchesSet = []
        }
        list.isVisibleOnlyReloadNeeded = true
    }
    
    // MARK: Selection

    func selectEntityAt(_ index: Int) {
        details.selectedEntity = messages[index]
        if let index = matches.firstIndex(where: { $0.index == index }) {
            selectedMatchIndex = index
        }
    }

    // MARK: Search (Matches)

    func isMatch(_ message: LoggerMessageEntity) -> Bool {
        matchesSet.contains(message.objectID)
    }

    func doneSearch() {
        self.searchTerm = ""
    }

    func nextMatch() {
        guard !matches.isEmpty else { return }
        updateMatchIndex(selectedMatchIndex + 1 < matches.count ? selectedMatchIndex + 1 : 0)
    }

    func previousMatch() {
        guard !matches.isEmpty else { return }
        updateMatchIndex(selectedMatchIndex - 1 < 0 ? matches.count - 1 : selectedMatchIndex - 1)
    }

    private func updateMatchIndex(_ newIndex: Int) {
        let previousIndex = selectedMatchIndex
        selectedMatchIndex = newIndex
        didUpdateCurrentSelectedMatch(previousMatch: previousIndex)
    }

    private func didUpdateCurrentSelectedMatch(previousMatch: Int? = nil) {
        guard !matches.isEmpty else { return }
        list.scrollToIndex = matches[selectedMatchIndex].index
        details.selectedEntity = messages[matches[selectedMatchIndex].index]
    }
    #endif

    // MARK: Quick Filters

    private func makeQuickFilters(criteria: ConsoleSearchCriteria) -> [QuickFilterViewModel] {
        var filters = [QuickFilterViewModel]()
        func addResetIfNeeded() {
            if !criteria.isDefault {
                filters.append(QuickFilterViewModel(title: "Reset", color: .secondary, imageName: "arrow.clockwise" ) { [weak self] in
                    self?.searchCriteria = .default
                })
            }
        }
        #if os(watchOS)
        addResetIfNeeded()
        #endif
        if !criteria.logLevels.isEnabled || criteria.logLevels.levels != [.error, .critical] {
            filters.append(QuickFilterViewModel(title: "Errors", color: .secondary, imageName: "exclamationmark.octagon") { [weak self] in
                self?.searchCriteria.logLevels.isEnabled = true
                self?.searchCriteria.logLevels.levels = [.error, .critical]
            })
        }
        #warning("TODO: [P01] Rework how these filters are implemented on watchOS")
        #if os(watchOS)
        if !criteria.onlyPins {
            filters.append(QuickFilterViewModel(title: "Pins", color: .secondary, imageName: "pin") { [weak self] in
                self?.searchCriteria.onlyPins = true
            })
        }
        if !criteria.onlyNetwork {
            filters.append(QuickFilterViewModel(title: "Networking", color: .secondary, imageName: "cloud") { [weak self] in
                self?.searchCriteria.onlyNetwork = true
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
                self?.searchCriteria.dates = .make(startDate: startDate, endDate: startDate + 86400)
            })
            filters.append(QuickFilterViewModel(title: "Recent", color: .secondary, imageName: "arrow.clockwise") { [weak self] in
                self?.searchCriteria.dates = .make(startDate: Date() - 1200, endDate: nil)
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
        #if os(macOS)
        self.list.elements = self.messages
        #endif
    }
}

enum ConsoleContentType {
    case all
    case network
    case pins
}

#if os(macOS)
final class ConsoleDetailsRouterViewModel: ObservableObject {
    @Published var selectedEntity: LoggerMessageEntity?

    private let context: AppContext

    init(context: AppContext) {
        self.context = context
    }

    func makeDetailsRouter(for message: LoggerMessageEntity) -> ConsoleMessageDetailsRouter {
        ConsoleMessageDetailsRouter(context: context, message: message)
    }
}

public struct ExternalEvents {
    /// - warning: Don't use it, it's used internally.
    public static var open: AnyView?
}

struct ConsoleMatch {
    let index: Int
    let objectID: NSManagedObjectID
}
#endif

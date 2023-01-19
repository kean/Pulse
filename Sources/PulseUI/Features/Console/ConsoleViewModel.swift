// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

final class ConsoleViewModel: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
    let title: String
    let isNetworkOnly: Bool
    let store: LoggerStore

    @Published private(set) var visibleEntities: ArraySlice<NSManagedObject> = []
    @Published private(set) var entities: [NSManagedObject] = []
    let entitiesSubject = CurrentValueSubject<[NSManagedObject], Never>([])

#if os(iOS)
    let insightsViewModel: InsightsViewModel
    @available(iOS 15, tvOS 15, *)
    var searchViewModel: ConsoleSearchViewModel {
        _searchViewModel as! ConsoleSearchViewModel
    }
    private var _searchViewModel: AnyObject?
#endif

    let searchBarViewModel: ConsoleSearchBarViewModel
    let searchCriteriaViewModel: ConsoleSearchCriteriaViewModel

    var toolbarTitle: String {
        let suffix = mode == .network ? "Requests" : "Messages"
        return "\(entities.count) \(suffix)"
    }

    @Published var mode: Mode
    @Published var isOnlyErrors = false
    @Published var filterTerm: String = ""

    var onDismiss: (() -> Void)?

    /// This exist strickly to workaround List performance issues
    private var scrollPosition: ScrollPosition = .nearTop
    private var visibleEntityCountLimit = fetchBatchSize
    private var visibleObjectIDs: Set<NSManagedObjectID> = []

    private var controller: NSFetchedResultsController<NSManagedObject>?
    private var isViewVisible = false
    private var cancellables: [AnyCancellable] = []

    enum Mode {
        case messages, network
    }

    init(store: LoggerStore, mode: Mode = .messages) {
        self.title = mode == .network ? "Network" : "Console"
        self.store = store
        self.mode = mode
        self.isNetworkOnly = mode == .network

        self.searchBarViewModel = ConsoleSearchBarViewModel()
        self.searchCriteriaViewModel = ConsoleSearchCriteriaViewModel(store: store, entities: entitiesSubject)

#if os(iOS)
        self.insightsViewModel = InsightsViewModel(store: store)
        if #available(iOS 15, *) {
            self._searchViewModel = ConsoleSearchViewModel(entities: entitiesSubject, store: store, searchBar: searchBarViewModel)
        }
#endif

        super.init()

        $entities.sink { [entitiesSubject] in
            entitiesSubject.send($0)
        }.store(in: &cancellables)

        $filterTerm
            .dropFirst()
            .throttle(for: 0.25, scheduler: RunLoop.main, latest: true)
            .sink { [weak self] filterTerm in
                self?.refresh(filterTerm: filterTerm)
            }.store(in: &cancellables)

        searchCriteriaViewModel.$criteria
            .dropFirst()
            .throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in self?.refreshNow() }
            .store(in: &cancellables)

        $isOnlyErrors.receive(on: DispatchQueue.main).dropFirst().sink { [weak self] _ in
            self?.refreshNow()
        }.store(in: &cancellables)

        prepare(for: mode)
    }

    // MARK: Mode

    func toggleMode() {
        switch mode {
        case .messages: mode = .network
        case .network: mode = .messages
        }
        prepare(for: mode)
    }

    private func prepare(for mode: Mode) {
        searchCriteriaViewModel.mode = mode

        let request = makeFetchRequest(for: mode)
        controller = NSFetchedResultsController(fetchRequest: request, managedObjectContext: store.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        controller?.delegate = self

        refreshNow()
    }

    // MARK: Appearance

    func onAppear() {
        isViewVisible = true
        reloadMessages(isMandatory: true)
    }

    func onDisappear() {
        isViewVisible = false
    }

    // MARK: Refresh

    private func refreshNow() {
        // important: order
        refresh(filterTerm: filterTerm)
#if os(iOS)
        if #available(iOS 15, *) {
            searchViewModel.refreshNow()
        }
#endif
    }

    private func refresh(filterTerm: String) {
        // Search messages
        guard let controller = controller else {
            return assertionFailure()
        }
        switch mode {
        case .messages:
            controller.fetchRequest.predicate = ConsoleSearchCriteria.makeMessagePredicates(criteria: searchCriteriaViewModel.criteria, isOnlyErrors: isOnlyErrors, filterTerm: filterTerm)
        case .network:
            controller.fetchRequest.predicate = ConsoleSearchCriteria.makeNetworkPredicates(criteria: searchCriteriaViewModel.criteria, isOnlyErrors: isOnlyErrors, filterTerm: filterTerm)
        }
        try? controller.performFetch()

        reloadMessages()
    }

    // MARK: - NSFetchedResultsControllerDelegate

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith diff: CollectionDifference<NSManagedObjectID>) {
        if isViewVisible {
            withAnimation {
                reloadMessages(isMandatory: false)
            }
        } else {
            entities = self.controller?.fetchedObjects ?? []
        }
    }

    private func reloadMessages(isMandatory: Bool = true) {
        entities = controller?.fetchedObjects ?? []
        if isMandatory || scrollPosition == .nearTop {
            refreshVisibleEntities()
        }
    }

    private enum ScrollPosition {
        case nearTop
        case middle
        case nearBottom
    }

    private func refreshVisibleEntities() {
        visibleEntities = entities.prefix(visibleEntityCountLimit)
    }

    func onDisappearCell(with objectID: NSManagedObjectID) {
        visibleObjectIDs.remove(objectID)
        refreshScrollPosition()
    }

    func onAppearCell(with objectID: NSManagedObjectID) {
        visibleObjectIDs.insert(objectID)
        refreshScrollPosition()
    }

    private func refreshScrollPosition() {
        let scrollPosition: ScrollPosition
        if visibleEntities.prefix(5).map(\.objectID).contains(where: visibleObjectIDs.contains) {
            scrollPosition = .nearTop
        } else if visibleEntities.suffix(5).map(\.objectID).contains(where: visibleObjectIDs.contains) {
            scrollPosition = .nearBottom
        } else {
            scrollPosition = .middle
        }

        if scrollPosition != self.scrollPosition {
            self.scrollPosition = scrollPosition
            switch scrollPosition {
            case .nearTop:
                visibleEntityCountLimit = fetchBatchSize // Reset
                refreshVisibleEntities()
            case .middle:
                break // Don't reload: too expensive and ruins gestures
            case .nearBottom:
                visibleEntityCountLimit += fetchBatchSize
                refreshVisibleEntities()
            }
        }
    }


    // MARK: - Sharing

    func prepareForSharing(as output: ShareOutput, _ completion: @escaping (ShareItems?) -> Void) {
        ShareService.share(entities, store: store, as: output, completion)
    }
}

private func makeFetchRequest(for mode: ConsoleViewModel.Mode) -> NSFetchRequest<NSManagedObject> {
    let request: NSFetchRequest<NSManagedObject>
    switch mode {
    case .messages:
        request = .init(entityName: "\(LoggerMessageEntity.self)")
        request.relationshipKeyPathsForPrefetching = ["request"]
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LoggerMessageEntity.createdAt, ascending: false)]
    case .network:
        request = .init(entityName: "\(NetworkTaskEntity.self)")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NetworkTaskEntity.createdAt, ascending: false)]
    }
    request.fetchBatchSize = fetchBatchSize
    return request
}

private let fetchBatchSize = 100


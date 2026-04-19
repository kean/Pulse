// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import Foundation
import CoreData
import Pulse

package protocol ConsoleSearchSessionDelegate: AnyObject {
    /// Delivers a chronologically-ordered batch of changes accumulated since
    /// the last flush. Callers apply events in order to stay in sync with
    /// the session's background state.
    func searchSession(_ session: ConsoleSearchSession, didEmit events: [ConsoleSearchSession.Event])
}

/// Owns a private-queue `searchContext` and an `NSFetchedResultsController` on
/// that context. All Core Data work — fetching, matching, live-update
/// observation — happens off the main thread; only event delivery hops to
/// main. A session is immutable on `(predicate, parameters)`; callers create a
/// fresh one when those inputs change.
///
/// Background work (scan progress, live inserts/removes) produces discrete
/// `Event`s that are queued on the main queue and delivered to the delegate
/// in periodic flushes (every `flushInterval`). Applying the delivered events
/// in order keeps the view in sync with the session.
package final class ConsoleSearchSession: NSObject {

    // MARK: Types

    package struct Result {
        package let objectID: NSManagedObjectID
        package let occurrences: [ConsoleSearchOccurrence]

        package init(objectID: NSManagedObjectID, occurrences: [ConsoleSearchOccurrence]) {
            self.objectID = objectID
            self.occurrences = occurrences
        }
    }

    /// A discrete change produced by the session. Events are emitted in
    /// chronological order; applying them in sequence mirrors the session's
    /// view of the data.
    package enum Event {
        /// Primary-search matches discovered since the last event.
        case results([Result])
        /// Primary search produced all results for the current cutoff. When
        /// `hasMore` is true, `loadMore()` expands the cutoff and resumes.
        case finished(hasMore: Bool)
        /// Extended-search matches discovered since the last event.
        case extendedResults([Result])
        /// Extended search produced all results for the current cutoff.
        case extendedFinished(hasMore: Bool)
        /// Live updates added `count` new matches. Counted, not appended,
        /// so the view can surface a refresh affordance.
        case newMatches(count: Int)
        /// Live updates removed previously-matched entities.
        case removedMatches(Set<NSManagedObjectID>)
    }

    // MARK: Public

    package let parameters: ConsoleSearchParameters
    package weak var delegate: ConsoleSearchSessionDelegate?

    /// Rolling cutoff for the primary search; grows on each `loadMore()`
    /// (same 20 → 1000 doubling cadence the old operation used).
    package var cutoff = 20

    // MARK: Inputs

    private let mode: ConsoleMode
    private let primaryPredicate: NSPredicate?
    private let extendedPredicate: NSPredicate?
    private let extendedFetchLimit: Int
    private let sortDescriptors: [NSSortDescriptor]

    // MARK: Private-queue state (only touched inside searchContext.perform)

    private let searchContext: NSManagedObjectContext
    private let service = ConsoleSearchService()
    private var primaryController: NSFetchedResultsController<NSManagedObject>?
    private var primaryScan = ScanState()
    /// IDs already emitted to the delegate; used to suppress duplicate
    /// emissions from live updates and to report removals.
    private var matchedIDs = Set<NSManagedObjectID>()

    private var extendedCandidateIDs: [NSManagedObjectID] = []
    private var extendedScan = ScanState()
    private var extendedCutoff = 20
    private var hasStartedExtended = false

    private struct ScanState {
        var index = 0
        var found = 0
    }

    // MARK: Main-queue state (only touched on main)

    private var pendingEvents: [Event] = []
    private var flushTimer: Timer?
    /// Each primary "page" (a scan run bounded by a `.finished`) gets one
    /// eager flush once its results cross `firstFlushThreshold`, so the user
    /// sees something fast. Subsequent events wait for the regular cadence.
    private var primaryWantsFirstFlush = true

    // MARK: Atomic

    private let lock = NSLock()
    private var _isCancelled = false

    private static let flushInterval: TimeInterval = 0.3
    private static let firstFlushThreshold = 10

    // MARK: Init

    package init(
        store: LoggerStoreProtocol,
        mode: ConsoleMode,
        primaryPredicate: NSPredicate?,
        extendedPredicate: NSPredicate? = nil,
        extendedFetchLimit: Int = 1000,
        sortDescriptors: [NSSortDescriptor],
        parameters: ConsoleSearchParameters
    ) {
        self.mode = mode
        self.primaryPredicate = primaryPredicate
        self.extendedPredicate = extendedPredicate
        self.extendedFetchLimit = extendedFetchLimit
        self.sortDescriptors = sortDescriptors
        self.parameters = parameters

        let context = store.newBackgroundContext()
        // `newBackgroundContext()` doesn't set this by default (see
        // LoggerStore.swift); without it, the FRC below wouldn't see inserts
        // from writes on sibling contexts.
        context.automaticallyMergesChangesFromParent = true
        self.searchContext = context

        super.init()
    }

    deinit {
        flushTimer?.invalidate()
    }

    // MARK: Lifecycle

    package func start() {
        searchContext.perform {
            guard !self.isCancelled else { return }
            let request = NSFetchRequest<NSManagedObject>(entityName: self.mode.entityName)
            request.predicate = self.primaryPredicate
            request.sortDescriptors = self.sortDescriptors
            request.fetchBatchSize = ConsoleDataSource.fetchBatchSize
            if self.mode != .network {
                request.relationshipKeyPathsForPrefetching = ["request"]
            }
            let controller = NSFetchedResultsController(
                fetchRequest: request,
                managedObjectContext: self.searchContext,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
            controller.delegate = self
            self.primaryController = controller
            do {
                try controller.performFetch()
            } catch {
                self.emit([.finished(hasMore: false)])
                return
            }
            self.scanPrimary()
        }
    }

    package func loadMore() {
        searchContext.perform {
            guard !self.isCancelled, self.primaryController != nil else { return }
            if self.cutoff < 1000 { self.cutoff *= 2 }
            self.scanPrimary()
        }
    }

    package func startExtendedSearch() {
        searchContext.perform {
            guard !self.isCancelled, !self.hasStartedExtended else { return }
            self.hasStartedExtended = true
            guard let predicate = self.extendedPredicate else {
                self.emit([.extendedFinished(hasMore: false)])
                return
            }
            let request = NSFetchRequest<NSManagedObjectID>(entityName: self.mode.entityName)
            request.resultType = .managedObjectIDResultType
            request.predicate = predicate
            request.sortDescriptors = self.sortDescriptors
            request.fetchLimit = self.extendedFetchLimit
            self.extendedCandidateIDs = (try? self.searchContext.fetch(request)) ?? []
            self.scanExtended()
        }
    }

    package func loadMoreExtended() {
        searchContext.perform {
            guard !self.isCancelled, self.hasStartedExtended else { return }
            if self.extendedCutoff < 1000 { self.extendedCutoff *= 2 }
            self.scanExtended()
        }
    }

    package func cancel() {
        lock.lock()
        _isCancelled = true
        lock.unlock()
        searchContext.perform {
            self.primaryController?.delegate = nil
            self.primaryController = nil
            self.extendedCandidateIDs = []
            self.matchedIDs = []
        }
        // Pending main-queue events and the flush timer self-clean on the
        // next `flush()` tick (≤300ms) via the `isCancelled` guard.
    }

    // MARK: Matching

    private func scanPrimary() {
        guard !isCancelled, let controller = primaryController else { return }
        let all = controller.fetchedObjects ?? []
        primaryScan.found = matchedIDs.count // re-anchor at running total
        let hasMore = scan(
            state: &primaryScan,
            candidateCount: all.count,
            cutoff: cutoff,
            fetchEntity: { all[$0] },
            deduplicate: true,
            onMatch: { result in self.emit([.results([result])]) }
        )
        emit([.finished(hasMore: hasMore)])
    }

    private func scanExtended() {
        guard !isCancelled else { return }
        let hasMore = scan(
            state: &extendedScan,
            candidateCount: extendedCandidateIDs.count,
            cutoff: extendedCutoff,
            fetchEntity: { try? self.searchContext.existingObject(with: self.extendedCandidateIDs[$0]) },
            deduplicate: false,
            onMatch: { result in self.emit([.extendedResults([result])]) }
        )
        emit([.extendedFinished(hasMore: hasMore)])
    }

    /// Walks `candidateCount` candidates from `state.index`, matching each via
    /// `ConsoleSearchMatcher` and invoking `onMatch` for each hit. Stops when
    /// `state.found > cutoff`, returning `hasMore: true` without consuming the
    /// cutoff-tripping candidate so the next call re-processes it. With
    /// `deduplicate`, candidates already in `matchedIDs` are skipped and
    /// successful matches are recorded there.
    private func scan(
        state: inout ScanState,
        candidateCount: Int,
        cutoff: Int,
        fetchEntity: (Int) -> NSManagedObject?,
        deduplicate: Bool,
        onMatch: (Result) -> Void
    ) -> Bool {
        while state.index < candidateCount, !isCancelled {
            guard let entity = fetchEntity(state.index) else {
                state.index += 1
                continue
            }
            if deduplicate, matchedIDs.contains(entity.objectID) {
                state.index += 1
                continue
            }
            if let occurrences = ConsoleSearchMatcher.search(entity, parameters: parameters, service: service) {
                state.found += 1
                if state.found > cutoff {
                    return true
                }
                if deduplicate {
                    matchedIDs.insert(entity.objectID)
                }
                onMatch(Result(objectID: entity.objectID, occurrences: occurrences))
            }
            state.index += 1
        }
        return false
    }

    // MARK: Event emission

    /// Appends `events` to the main-queue buffer. Safe to call from any queue.
    /// The flush timer delivers the buffered events to the delegate as a
    /// single array every `flushInterval`.
    private func emit(_ events: [Event]) {
        guard !events.isEmpty else { return }
        DispatchQueue.main.async {
            guard !self.isCancelled else { return }
            for event in events {
                self.appendPendingEvent(event)
            }
            self.startFlushTimerIfNeeded()
        }
    }

    /// Collapses consecutive `.results` / `.extendedResults` events so the
    /// delegate sees one merged batch per type per flush, regardless of how
    /// many one-by-one emits the scan produced. Also triggers an eager first
    /// flush per page once results cross `firstFlushThreshold`.
    private func appendPendingEvent(_ event: Event) {
        dispatchPrecondition(condition: .onQueue(.main))
        let lastIndex = pendingEvents.count - 1
        if case .results(let new) = event, case .results(let existing) = pendingEvents.last {
            pendingEvents[lastIndex] = .results(existing + new)
        } else if case .extendedResults(let new) = event, case .extendedResults(let existing) = pendingEvents.last {
            pendingEvents[lastIndex] = .extendedResults(existing + new)
        } else {
            pendingEvents.append(event)
        }

        switch event {
        case .results:
            if primaryWantsFirstFlush,
               case .results(let results) = pendingEvents.last,
               results.count >= Self.firstFlushThreshold {
                primaryWantsFirstFlush = false
                flush()
            }
        case .finished:
            primaryWantsFirstFlush = true
        case .extendedResults, .extendedFinished, .newMatches, .removedMatches:
            break
        }
    }

    private func startFlushTimerIfNeeded() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard flushTimer == nil else { return }
        // Use `.common` mode so the timer still fires during scroll and other
        // tracking run-loop modes.
        let timer = Timer(timeInterval: Self.flushInterval, repeats: true) { [weak self] _ in
            self?.flush()
        }
        RunLoop.main.add(timer, forMode: .common)
        flushTimer = timer
    }

    private func flush() {
        dispatchPrecondition(condition: .onQueue(.main))
        if isCancelled {
            flushTimer?.invalidate()
            flushTimer = nil
            pendingEvents = []
            return
        }
        if pendingEvents.isEmpty {
            flushTimer?.invalidate()
            flushTimer = nil
            return
        }
        let events = pendingEvents
        pendingEvents = []
        delegate?.searchSession(self, didEmit: events)
    }

    // MARK: Cancellation

    private var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isCancelled
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension ConsoleSearchSession: NSFetchedResultsControllerDelegate {
    package func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChangeContentWith diff: CollectionDifference<NSManagedObjectID>
    ) {
        // Fires on `searchContext`'s queue.
        guard !isCancelled, controller === primaryController else { return }
        var newCount = 0
        var removed = Set<NSManagedObjectID>()
        for change in diff {
            switch change {
            case .insert(_, let id, _):
                guard !matchedIDs.contains(id),
                      let entity = try? searchContext.existingObject(with: id),
                      ConsoleSearchMatcher.search(entity, parameters: parameters, service: service) != nil else {
                    continue
                }
                matchedIDs.insert(id)
                newCount += 1
            case .remove(_, let id, _):
                if matchedIDs.remove(id) != nil {
                    removed.insert(id)
                }
            }
        }
        var events: [Event] = []
        if newCount > 0 { events.append(.newMatches(count: newCount)) }
        if !removed.isEmpty { events.append(.removedMatches(removed)) }
        emit(events)
    }
}

#endif

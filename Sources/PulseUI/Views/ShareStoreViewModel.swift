// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import CoreData
import Pulse
import Combine

@MainActor final class ShareStoreViewModel: ObservableObject {
    // Sharing options
    @Published var sessions: Set<UUID> = []
    @Published var level: LoggerStore.Level
    @Published var output: ShareStoreOutput

    @Published private(set) var isPreparingForSharing = false
    @Published private(set) var errorMessage: String?
    @Published var shareItems: ShareItems?

    var store: LoggerStore?

    init() {
        level = ConsoleSettings.shared.sharingLevel
        output = ConsoleSettings.shared.sharingOutput
    }

    func buttonSharedTapped() {
        guard !isPreparingForSharing else { return }
        isPreparingForSharing = true
        saveSharingOptions()
        prepareForSharing()
    }

    private func saveSharingOptions() {
        ConsoleSettings.shared.sharingLevel = level
        ConsoleSettings.shared.sharingOutput = output
    }

    func prepareForSharing() {
        guard let store = store else { return }

        isPreparingForSharing = true
        shareItems = nil
        errorMessage = nil

        Task {
            do {
                self.shareItems = try await prepareForSharing(store: store, predicate: predicate, output: output)
            } catch {
                guard !(error is CancellationError) else { return }
                self.errorMessage = error.localizedDescription
            }
            self.isPreparingForSharing = false
        }
    }

#warning("add sessions predicate")
    private var predicate: NSPredicate? {
        var predicates: [NSPredicate] = []
        if level == .trace {
            return nil
        }
        if level != .trace {
            predicates.append(.init(format: "level >= %i", level.rawValue))
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    private func prepareForSharing(store: LoggerStore, predicate: NSPredicate?, output: ShareStoreOutput) async throws -> ShareItems {
        switch output {
        case .store:
            return try await prepareStoreForSharing(store: store, predicate: predicate)
        case .text, .html:
            let output: ShareOutput = output == .text ? .plainText : .html
            return try await prepareForSharing(store: store, output: output, predicate: predicate)
        }
    }

    private func prepareStoreForSharing(store: LoggerStore, predicate: NSPredicate?) async throws -> ShareItems {
        let directory = TemporaryDirectory()

        let logsURL = directory.url.appendingPathComponent("logs-\(makeCurrentDate()).\(output.fileExtension)")
        try await store.export(to: logsURL, options: .init(predicate: predicate))
        return ShareItems([logsURL], cleanup: directory.remove)
    }

    private func prepareForSharing(store: LoggerStore, output: ShareOutput, predicate: NSPredicate?) async throws -> ShareItems {
        let entities = try await withUnsafeThrowingContinuation { continuation in
            store.backgroundContext.perform {
                let request = NSFetchRequest<LoggerMessageEntity>(entityName: "\(LoggerMessageEntity.self)")
                request.predicate = predicate
                let result = Result(catching: { try store.backgroundContext.fetch(request) })
                continuation.resume(with: result)
            }
        }
        return try await ShareService.share(entities, store: store, as: output)
    }
}

#endif

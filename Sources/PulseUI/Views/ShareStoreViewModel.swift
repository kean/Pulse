// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(watchOS)

import SwiftUI
import CoreData
import Pulse
import Combine

@MainActor final class ShareStoreViewModel: ObservableObject {
    // Sharing options
    @Published var sessions: Set<UUID> = []
    @Published var logLevels = Set(LoggerStore.Level.allCases)
    @Published var output: ShareStoreOutput

    @Published private(set) var isPreparingForSharing = false
    @Published private(set) var errorMessage: String?
    @Published var shareItems: ShareItems?

    var store: LoggerStore?

    init() {
        output = UserSettings.shared.sharingOutput
    }

    func buttonSharedTapped() {
        guard !isPreparingForSharing else { return }
        isPreparingForSharing = true
        saveSharingOptions()
        prepareForSharing()
    }

    private func saveSharingOptions() {
        UserSettings.shared.sharingOutput = output
    }

    func prepareForSharing() {
        guard let store = store else { return }

        isPreparingForSharing = true
        shareItems = nil
        errorMessage = nil

        Task {
            do {
                let options = LoggerStore.ExportOptions(predicate: predicate, sessions: sessions)
                self.shareItems = try await prepareForSharing(store: store, options: options)
            } catch {
                guard !(error is CancellationError) else { return }
                self.errorMessage = error.localizedDescription
            }
            self.isPreparingForSharing = false
        }
    }

    var selectedLevelsTitle: String {
        if logLevels.count == 1 {
            return logLevels.first!.name.capitalized
        } else if logLevels.count == 0 {
            return "–"
        } else if logLevels == [.error, .critical] {
            return "Errors"
        } else if logLevels == [.warning, .error, .critical] {
            return "Warnings & Errors"
        } else if logLevels.count == LoggerStore.Level.allCases.count {
            return "All"
        } else {
            return "\(logLevels.count)"
        }
    }

    private var predicate: NSPredicate? {
        var predicates: [NSPredicate] = []
        if logLevels != Set(LoggerStore.Level.allCases) {
            predicates.append(.init(format: "level IN %@", logLevels.map(\.rawValue)))
        }
        if !sessions.isEmpty {
            predicates.append(.init(format: "session IN %@", sessions))
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    private func prepareForSharing(store: LoggerStore, options: LoggerStore.ExportOptions) async throws -> ShareItems {
        switch output {
        case .store:
            return try await prepareStoreForSharing(store: store, as: .archive, options: options)
        case .package:
            return try await prepareStoreForSharing(store: store, as: .package, options: options)
        case .text, .html:
            let output: ShareOutput = output == .text ? .plainText : .html
            return try await prepareForSharing(store: store, output: output, options: options)
        }
    }

    private func prepareStoreForSharing(store: LoggerStore, as docType: LoggerStore.DocumentType, options: LoggerStore.ExportOptions) async throws -> ShareItems {
        let directory = TemporaryDirectory()

        let logsURL = directory.url.appendingPathComponent("logs-\(makeCurrentDate()).\(output.fileExtension)")
        try await store.export(to: logsURL, as: docType, options: options)
        return ShareItems([logsURL], cleanup: directory.remove)
    }

    private func prepareForSharing(store: LoggerStore, output: ShareOutput, options: LoggerStore.ExportOptions) async throws -> ShareItems {
        let entities = try await withUnsafeThrowingContinuation { continuation in
            store.backgroundContext.perform {
                let request = NSFetchRequest<LoggerMessageEntity>(entityName: "\(LoggerMessageEntity.self)")
                request.predicate = options.predicate // important: contains sessions
                let result = Result(catching: { try store.backgroundContext.fetch(request) })
                continuation.resume(with: result)
            }
        }
        return try await ShareService.share(entities, store: store, as: output)
    }
}

#endif

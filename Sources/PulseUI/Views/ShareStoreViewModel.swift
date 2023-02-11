// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import CoreData
import Pulse
import Combine

final class ShareStoreViewModel: ObservableObject {
    // Sharing options
    @Published var timeRange: SharingTimeRange
    @Published var level: LoggerStore.Level
    @Published var output: ShareStoreOutput

    // Settings
    @Published private(set) var isPreparingForSharing = false
    @Published private(set) var sharedContents: SharedContents?
    @Published private(set) var errorMessage: String?

    private var store: LoggerStore?
    private var isPrepareForSharingNeeded = false
    private var cancellable: AnyCancellable?

    init() {
        timeRange = ConsoleSettings.shared.sharingTimeRange
        level = ConsoleSettings.shared.sharingLevel
        output = ConsoleSettings.shared.sharingOutput
    }

    func display(_ store: LoggerStore) {
        guard self.store !== store else {
            return
        }

        self.store = store

        if cancellable == nil {
            cancellable = Publishers.CombineLatest3($timeRange, $output, $level)
                .dropFirst()
                .throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true)
                .sink { [weak self] _, _, _ in
                    self?.saveSharingOptions()
                    self?.setNeedsPrepareForSharing()
                }
        }

        self.prepareForSharing()
    }

    private func setNeedsPrepareForSharing() {
        if isPreparingForSharing {
            isPrepareForSharingNeeded = true
        } else {
            prepareForSharing()
        }
    }

    private func saveSharingOptions() {
        ConsoleSettings.shared.sharingTimeRange = timeRange
        ConsoleSettings.shared.sharingLevel = level
        ConsoleSettings.shared.sharingOutput = output
    }

    func prepareForSharing() {
        guard let store = store else { return }

        isPreparingForSharing = true
        sharedContents = nil
        errorMessage = nil

        let context = store.backgroundContext
        let predicate = self.predicate
        let output = self.output
        context.perform {
            self.prepareForSharing(store: store, context: context, predicate: predicate, output: output)
        }
    }

    private var predicate: NSPredicate? {
        if timeRange == .all && level == .trace {
            return nil
        }
        var predicates: [NSPredicate] = []
        switch timeRange {
        case .currentSession:
            predicates.append(.init(format: "sessionID == %i", store?.sessionID ?? Int64.max))
        case .lastHour:
            predicates.append(.init(format: "createdAt >= %@", Date().addingTimeInterval(-3600) as NSDate))
        case .today:
            let cutoffDate = Calendar.current.startOfDay(for: Date())
            predicates.append(.init(format: "createdAt >= %@", cutoffDate as NSDate))
        case .all:
            break
        }
        if level != .trace {
            predicates.append(.init(format: "level >= %i", level.rawValue))
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    private func prepareForSharing(store: LoggerStore, context: NSManagedObjectContext, predicate: NSPredicate?, output: ShareStoreOutput) {
        let directory = TemporaryDirectory()
        do {
            switch output {
            case .store:
                let contents = try prepareStoreForSharing(store: store, context: context, directory: directory, predicate: predicate)
                DispatchQueue.main.async {
                    self.sharedContents = contents
                    self.didFinishPreparingForSharing()
                }
            case .text, .html:
                let output: ShareOutput = output == .text ? .plainText : .html
                prepareForSharing(predicate: predicate, context: context, output: output) { contents in
                    DispatchQueue.main.async {
                        self.sharedContents = contents
                        self.didFinishPreparingForSharing()
                    }
                }
            }

        } catch {
            directory.remove()
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.didFinishPreparingForSharing()
            }
        }
    }

    private func didFinishPreparingForSharing() {
        if isPrepareForSharingNeeded {
            isPrepareForSharingNeeded = false
            prepareForSharing()
        } else {
            isPreparingForSharing = false
        }
    }

    private func prepareStoreForSharing(store: LoggerStore, context: NSManagedObjectContext, directory: TemporaryDirectory, predicate: NSPredicate?) throws -> SharedContents {
        let logsURL = directory.url.appendingPathComponent("logs-\(makeCurrentDate()).\(output.fileExtension)")
        let info: LoggerStore.Info?
        if let predicate = predicate {
            info = try store.copy(to: logsURL, predicate: predicate)
        } else {
            info = try store.copy(to: logsURL)
        }
        let item = ShareItems([logsURL], cleanup: directory.remove)
        return SharedContents(item: item, size: try logsURL.getFileSize(), info: info)
    }

    private func prepareForSharing(predicate: NSPredicate?, context: NSManagedObjectContext, output: ShareOutput, _ completion: @escaping (SharedContents) -> Void) {
        let request = NSFetchRequest<LoggerMessageEntity>(entityName: "\(LoggerMessageEntity.self)")
        request.predicate = predicate
        let messages = (try? context.fetch(request)) ?? []

        ShareStoreTask(entities: messages, store: store!, output: output) { item in
            guard let item = item else { return }
            completion(SharedContents(item: item, size: item.size))
        }.start()
    }
}

private extension URL {
    func getFileSize() throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        return attributes[.size] as? Int64 ?? 0
    }
}

struct SharedContents {
    var item: ShareItems?
    var size: Int64?
    var info: LoggerStore.Info?

    var formattedFileSize: String? {
        size.map(ByteCountFormatter.string)
    }
}

enum SharingTimeRange: String, CaseIterable, RawRepresentable {
    case currentSession = "This Session"
    case lastHour = "Last Hour"
    case today = "Today"
    case all = "All Messages"
}

#endif

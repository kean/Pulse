// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData
import SwiftUI
import Pulse

final class ShareStoreTask {
    private var isCancelled = false
    private var objectIDs: [NSManagedObjectID]
    private let renderer = TextRenderer(options: .sharing)
    private let store: LoggerStore
    private let output: ShareOutput
    private let context: NSManagedObjectContext
    private var completion: ((ShareItems?) -> Void)?

    init(entities: [NSManagedObject], store: LoggerStore, output: ShareOutput, completion: @escaping (ShareItems?) -> Void) {
        self.objectIDs = entities.map(\.objectID)
        self.store = store
        self.output = output
        self.context = store.backgroundContext
        self.completion = completion
    }

    func cancel() { // Not yet implemented
        isCancelled = true
        completion?(nil)
        completion = nil
    }

    func start() {
        context.perform {
            self.prepareForSharing()
        }
    }

    /// - warning: For testing purposes only.
    func share() -> ShareItems {
        ShareService.share(renderAsAttributedString(), as: output)
    }

    private func prepareForSharing() {
        let string = renderAsAttributedString()

        if output == .pdf { // Can only be used on the main thread
            DispatchQueue.main.async {
                let items = ShareService.share(string, as: self.output)
                self.didComplete(with: items)
            }
        } else {
            let items = ShareService.share(string, as: output)
            self.didComplete(with: items)
        }
    }

    private func didComplete(with items: ShareItems) {
        DispatchQueue.main.async {
            self.completion?(items)
            self.completion = nil
        }
    }

    private func renderAsAttributedString() -> NSAttributedString {
        prerenderResponseBodies()

        let content = contentForSharing(count: objectIDs.count)
        for index in objectIDs.indices {
            guard let entity = try? context.existingObject(with: objectIDs[index]) else {
                continue
            }
            switch LoggerEntity(entity) {
            case .message(let message):
                renderer.render(message)
            case .task(let task):
                renderer.render(task, content: content)
            }
            if index < objectIDs.endIndex - 1 {
                renderer.addSpacer()
            }
        }
        return renderer.make()
    }

    // Unlike the rest of the processing it's easy to parallelize and it
    // usually takes up at least 90% of processing.
    private func prerenderResponseBodies() {
        var jobs: [NSManagedObjectID: RenderBodyJob] = [:]

        func enqueueJob(for blob: LoggerBlobHandleEntity, error: NetworkLogger.DecodingError?) {
            jobs[blob.objectID] = RenderBodyJob(
                data: LoggerBlobHandleEntity.getData(for: blob, store: store),
                contentType: blob.contentType,
                error: error
            )
        }

        for objectID in objectIDs {
            if let object = try? context.existingObject(with: objectID),let task = LoggerEntity(object).task {
                if let blob = task.responseBody, jobs[blob.objectID] == nil {
                    enqueueJob(for: blob, error: task.decodingError)
                }
                if let blob = task.requestBody, jobs[blob.objectID] == nil {
                    enqueueJob(for: blob, error: nil)
                }
            }
        }

        let queue = Array(jobs)
        let indices = queue.indices
        // "To get the maximum benefit of this function, configure the number of
        // iterations to be at least three times the number of available cores."
        let iterations = indices.count >= 32 ? 32 : (indices.count >= 8 ? 8 : 1)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: iterations) { index in
            let start = index * indices.count / iterations
            let end = (index + 1) * indices.count / iterations

            for index in start..<end {
                let job = queue[index]
                guard let data = job.value.data() else { continue }
                let string = TextRenderer(options: .sharing).render(data, contentType: job.value.contentType, error: job.value.error)

                lock.lock()
                renderer.renderedBodies[job.key] = string
                lock.unlock()
            }
        }
    }

    private struct RenderBodyJob {
        let data: () -> Data?
        let contentType: NetworkLogger.ContentType?
        let error: NetworkLogger.DecodingError?
    }
}

private func contentForSharing(count: Int) -> NetworkContent {
    var content = NetworkContent.sharing
    if count > 1 {
        content.remove(.largeHeader)
        content.insert(.header)
    }
    return content
}

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData
import SwiftUI
import Pulse

#warning("TODO: make store accesor from BlobEntity private")

final class ShareStoreTask: ObservableObject {
    @Published var title: String = "Preparing..."
    @Published var progress: Float = 0

    private var isCancelled = false
    private var objectIDs: [NSManagedObjectID]
    private let renderer = TextRenderer(options: .sharing)
    private let store: LoggerStore
    private let output: ShareOutput
    private let context: NSManagedObjectContext

    init(entities: [NSManagedObject], store: LoggerStore, output: ShareOutput) {
        self.objectIDs = entities.map(\.objectID)
        self.store = store
        self.output = output
        self.context = store.backgroundContext
    }

    func cancel() {
        isCancelled = true
    }

    func start() {
        context.perform {
            self.prepareForSharing()
        }
    }

    private func prepareForSharing() {
        prerenderResponseBodies()
        let string = renderAttributedString()

        #warning("TODO: convert to actual output")
        self.title = "Completed"
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
            if let object = try? context.existingObject(with: objectID), let task = getTask(for: object) {
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
                let completed = renderer.renderedBodies.count
                DispatchQueue.main.async {
                    self.progress = (Float(completed) / Float(indices.count)) * (self.output.progressScale / 2.0)
                }
                lock.unlock()
            }
        }
    }

    private func renderAttributedString() -> NSAttributedString {
        let content = contentForSharing(count: objectIDs.count)
        for index in objectIDs.indices {
            guard let entity = try? context.existingObject(with: objectIDs[index]) else {
                continue
            }

            if let task = entity as? NetworkTaskEntity {
                renderer.render(task, content: content)
            } else if let message = entity as? LoggerMessageEntity {
                if let task = message.task {
                    renderer.render(task, content: content)
                } else {
                    renderer.render(message)
                }
            } else {
                fatalError("Unsuppported entity: \(entity)")
            }
            if index < objectIDs.endIndex - 1 {
                renderer.addSpacer()
            }
            DispatchQueue.main.async {
                self.progress = (self.output.progressScale / 2.0) + (Float(index) / Float(self.objectIDs.count)) * (self.output.progressScale / 2.0)
            }
        }
        return renderer.make()
    }

    private struct RenderBodyJob {
        let data: () -> Data?
        let contentType: NetworkLogger.ContentType?
        let error: NetworkLogger.DecodingError?
    }
}

private extension ShareOutput {
    var progressScale: Float {
        switch self {
        case .plainText: return 0.9
        case .html: return 0.5
        case .pdf: return 0.2
        }
    }
}

private func getTask(for object: NSManagedObject) -> NetworkTaskEntity? {
    (object as? NetworkTaskEntity) ?? (object as? LoggerMessageEntity)?.task
}

private func contentForSharing(count: Int) -> NetworkContent {
    var content = NetworkContent.sharing
    if count > 1 {
        content.remove(.largeHeader)
        content.insert(.header)
    }
    return content
}

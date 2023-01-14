// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData
import SwiftUI
import Pulse

final class ShareStoreTask: ObservableObject {
    @Published var title: String = "Preparing..."
    @Published var value: Float = 0

    private let entities: [NSManagedObject]
    private let renderer = TextRenderer(options: .sharing)

    init(entities: [NSManagedObject]) {
        self.entities = entities
    }

    func start() {
        prepareForSharing()
    }

    private func prepareForSharing() {
        prerenderResponseBodies()

//        let content = contentForSharing(entities)
//        for index in entities.indices {
//            let entity = entities[index]
//            if let task = entity as? NetworkTaskEntity {
//                renderer.render(task, content: content)
//            } else if let message = entity as? LoggerMessageEntity {
//                if let task = message.task {
//                    renderer.render(task, content: content)
//                } else {
//                    renderer.render(message)
//                }
//            } else {
//                fatalError("Unsuppported entity: \(entity)")
//            }
//            if index < entities.endIndex - 1 {
//                renderer.addSpacer()
//            }
//        }
//        return renderer.make()
    }

    // Unlike the rest of the processing it's easy to parallelize and it
    // usually takes up at least 90% of processing.
    private func prerenderResponseBodies() {
        struct RenderBodyJob {
            let data: () -> Data?
            let contentType: NetworkLogger.ContentType?
            let error: NetworkLogger.DecodingError?
        }

        var jobs: [NSManagedObjectID: RenderBodyJob] = [:]
        var store: LoggerStore?

        func enqueueJob(for blob: LoggerBlobHandleEntity, error: NetworkLogger.DecodingError?) {
            if store == nil { store = blob.store }
            guard let store = store else { return } // Should never happen
            jobs[blob.objectID] = RenderBodyJob(
                data: LoggerBlobHandleEntity.getData(for: blob, store: store),
                contentType: blob.contentType,
                error: error
            )
        }

        for entity in entities {
            guard let task = getTask(for: entity) else { continue }
            if let blob = task.responseBody, jobs[blob.objectID] == nil {
                enqueueJob(for: blob, error: task.decodingError)
            }
            if let blob = task.requestBody, jobs[blob.objectID] == nil {
                enqueueJob(for: blob, error: nil)
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

                #warning("TODO: fix")
                lock.lock()
//                self.renderedBodies[job.key] = string
                lock.unlock()
            }
        }
    }

    private func getTask(for object: NSManagedObject) -> NetworkTaskEntity? {
        (object as? NetworkTaskEntity) ?? (object as? LoggerMessageEntity)?.task
    }

    private static func contentForSharing(_ entities: [NSManagedObject]) -> NetworkContent {
        var content = NetworkContent.sharing
        if entities.count > 1 {
            content.remove(.largeHeader)
            content.insert(.header)
        }
        return content
    }
}


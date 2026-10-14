// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData
import SwiftUI

final class ShareStoreTask {
    private var isCancelled = false
    private var objectIDs: [NSManagedObjectID]
    private let renderer = TextRenderer(options: .sharing)
    /// The bodies that bypass the HTML conversion, by their placeholders.
    private var largeBodies: [String: String] = [:]
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
        switch output {
        case .har: return shareAsHAR()
        case .html: return shareAsHTML()
        case .plainText: return shareAsPlainText()
        case .pdf: return ShareService.share(renderAsAttributedString(), as: output)
        }
    }

    private func prepareForSharing() {
        switch output {
        case .har:
            didComplete(with: shareAsHAR())
            return
        case .html:
            didComplete(with: shareAsHTML())
            return
        case .plainText:
            didComplete(with: shareAsPlainText())
            return
        case .pdf:
            break
        }

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

    /// Writes the document straight to a file to avoid holding every response
    /// body in memory at once.
    private func shareAsHAR() -> ShareItems {
        let directory = TemporaryDirectory()
        let fileURL = directory.url.appendingPathComponent("logs-\(makeCurrentDate()).har", isDirectory: false)
        do {
            let size = try HARDocument.write(objectIDs, context: context, to: fileURL)
            return ShareItems([fileURL], size: size, cleanup: directory.remove)
        } catch {
            directory.remove()
            return ShareItems(["Failed to create a HAR document: \(error.localizedDescription)"])
        }
    }

    private func shareAsHTML() -> ShareItems {
        let directory = TemporaryDirectory()
        let fileURL = directory.url.appendingPathComponent("logs-\(makeCurrentDate()).html", isDirectory: false)
        do {
            let writer = try HTMLDocumentWriter(url: fileURL)
            try renderInBatches { string in
                let html = try TextUtilities.html(from: ShareService.sanitized(string, as: .html))
                try writer.append(html, largeBodies: largeBodies)
                largeBodies.removeAll()
            }
            let size = try writer.finish()
            return ShareItems([fileURL], size: size, cleanup: directory.remove)
        } catch {
            directory.remove()
            return ShareItems(["Failed to create an HTML document: \(error.localizedDescription)"])
        }
    }

    /// Shares the text as a string, like the other plain text outputs, unless
    /// it's too large to be passed around in memory, in which case it's shared
    /// as a file.
    private func shareAsPlainText() -> ShareItems {
        let directory = TemporaryDirectory()
        let fileURL = directory.url.appendingPathComponent("logs-\(makeCurrentDate()).txt", isDirectory: false)
        do {
            guard FileManager.default.createFile(atPath: fileURL.path, contents: nil) else {
                throw CocoaError(.fileWriteUnknown)
            }
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try renderInBatches { string in
                let text = TextUtilities.plainText(from: ShareService.sanitized(string, as: .plainText))
                try handle.write(contentsOf: Data(text.utf8))
            }
            let size = Int64(try handle.offset())
            if size <= plainTextInlineSizeLimit, let text = try? String(contentsOf: fileURL, encoding: .utf8) {
                directory.remove()
                return ShareItems([text])
            }
            return ShareItems([fileURL], size: size, cleanup: directory.remove)
        } catch {
            directory.remove()
            return ShareItems(["Failed to share logs as text: \(error.localizedDescription)"])
        }
    }

    /// Renders the entities in batches and passes each one to `write`, so
    /// that the memory usage is bound by the size of a batch rather than by
    /// the total size of the logs.
    private func renderInBatches(_ write: (NSAttributedString) throws -> Void) throws {
        for batch in makeBatches() {
            try autoreleasepool {
                let string = render(objectIDs[batch])
                if batch.upperBound < objectIDs.endIndex {
                    renderer.addSpacer()
                }
                try write(string)
                for objectID in objectIDs[batch] {
                    if let object = try? context.existingObject(with: objectID) {
                        context.refresh(object, mergeChanges: false)
                    }
                }
            }
        }
    }

    /// Splits the entities into batches with request and response bodies of
    /// about `batchBodySizeLimit` in total.
    private func makeBatches() -> [Range<Int>] {
        let batchBodySizeLimit: Int64 = 1048576
        let batchCountLimit = 500

        var batches: [Range<Int>] = []
        var start = objectIDs.startIndex
        var bodySize: Int64 = 0
        for index in objectIDs.indices {
            if let object = try? context.existingObject(with: objectIDs[index]),
               let task = LoggerEntity(object).task {
                bodySize += max(0, task.requestBodySize) + max(0, task.responseBodySize)
            }
            if bodySize >= batchBodySizeLimit || index - start + 1 >= batchCountLimit {
                batches.append(start..<(index + 1))
                start = index + 1
                bodySize = 0
            }
        }
        if start < objectIDs.endIndex {
            batches.append(start..<objectIDs.endIndex)
        }
        return batches
    }

    private func renderAsAttributedString() -> NSAttributedString {
        render(objectIDs[...])
    }

    private func render(_ objectIDs: ArraySlice<NSManagedObjectID>) -> NSAttributedString {
        prerenderResponseBodies(for: objectIDs)
        defer { renderer.renderedBodies.removeAll() }

        let content = contentForSharing(count: self.objectIDs.count)
        for index in objectIDs.indices {
            guard let entity = try? context.existingObject(with: objectIDs[index]) else {
                continue
            }
            switch LoggerEntity(entity) {
            case .message(let message):
                renderer.render(message)
            case .task(let task):
                renderer.render(task, content: content, store: store)
            }
            if index < objectIDs.endIndex - 1 {
                renderer.addSpacer()
            }
        }
        return renderer.make()
    }

    // Unlike the rest of the processing it's easy to parallelize and it
    // usually takes up at least 90% of processing.
    private func prerenderResponseBodies(for objectIDs: ArraySlice<NSManagedObjectID>) {
        var jobs: [NSManagedObjectID: RenderBodyJob] = [:]

        func enqueueJob(for blob: LoggerBlobHandleEntity, error: NetworkLogger.DecodingError?) {
            jobs[blob.objectID] = RenderBodyJob(
                data: LoggerBlobHandleEntity.getData(for: blob, store: store),
                contentType: blob.contentType,
                error: error
            )
        }

        for objectID in objectIDs {
            if let object = try? context.existingObject(with: objectID), let task = LoggerEntity(object).task {
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
                let bodyRenderer = TextRenderer(options: .sharing)
                let string: NSAttributedString
                var largeBody: (placeholder: String, text: String)?
                if data.count <= highlightingSizeLimit {
                    string = bodyRenderer.render(data, contentType: job.value.contentType, error: job.value.error)
                } else if output == .html {
                    let placeholder = HTMLDocumentWriter.makePlaceholder()
                    largeBody = (placeholder, makePlainText(from: data))
                    string = bodyRenderer.preformatted(placeholder)
                } else {
                    string = bodyRenderer.preformatted(makePlainText(from: data))
                }

                lock.lock()
                renderer.renderedBodies[job.key] = string
                if let largeBody {
                    largeBodies[largeBody.placeholder] = largeBody.text
                }
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

/// Highlighting splits a body into a run per token, and the HTML conversion
/// wraps every line and run of spaces into its own element, so a body of a few
/// megabytes takes gigabytes of memory. The larger bodies are shared without
/// highlighting and are written to HTML directly.
private let highlightingSizeLimit = 512 * 1024

private let plainTextInlineSizeLimit: Int64 = 512 * 1024

private func makePlainText(from data: Data) -> String {
    if let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
       let formatted = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .withoutEscapingSlashes, .fragmentsAllowed]) {
        return String(decoding: formatted, as: UTF8.self)
    }
    return String(data: data, encoding: .utf8) ?? ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
}

private func contentForSharing(count: Int) -> NetworkContent {
    var content = NetworkContent.sharing
    if count > 1 {
        content.remove(.largeHeader)
        content.insert(.header)
    }
    return content
}

//
//  AlamofireIntegration.swift
//  Pulse
//
//  Created by Bagus andinata on 21/08/21.
//  Copyright © 2021 kean. All rights reserved.
//

import Foundation
import Alamofire
import Pulse

typealias Session = Alamofire.Session

// MARK: - Example Provider

final class ExampleProvider {
    private let eventMonitors: [EventMonitor]
    private let logger: NetworkLogger
    private let session: Session

    init() {
        logger = NetworkLogger()
        eventMonitors = [NetworkLoggerEventMonitor(logger: logger)]
        session = Alamofire.Session(eventMonitors: eventMonitors)
    }

    func request(_ request: URLRequestConvertible) -> DataRequest {
        return session.request(request)
    }
}

// MARK: - LOGGER EVENT

struct NetworkLoggerEventMonitor: EventMonitor {
    let logger: NetworkLogger

    func request(_ request: Request, didCreateTask task: URLSessionTask) {
        logger.logTaskCreated(task)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        logger.logDataTask(dataTask, didReceive: data)

        guard let response = dataTask.response else { return }
        logger.logDataTask(dataTask, didReceive: response)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        logger.logTask(task, didFinishCollecting: metrics)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        logger.logTask(task, didCompleteWithError: error)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse) {
        logger.logDataTask(dataTask, didReceive: proposedResponse.response)
    }
}

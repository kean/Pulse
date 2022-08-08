//
//  MoyaIntegration.swift
//  Pulse
//
//  Created by Bagus andinata on 21/08/21.
//  Copyright © 2021 kean. All rights reserved.
//

import Foundation
import Moya
import Alamofire
import PulseLogHandler

// MARK: - EXAMPLE PROVIDER WITH LOGGER
let ExampleProvider: MoyaProvider<ExampleEndpoints> = {
    let logger: NetworkLogger = NetworkLogger()
    let eventMonitors: [EventMonitor] = [NetworkLoggerEventMonitor(logger: logger)]
    let session = Alamofire.Session(eventMonitors: eventMonitors)
    return MoyaProvider<ExampleEndpoints>(session: session)
}()

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

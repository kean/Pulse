// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore
import Combine
import CoreData

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
final class ConsoleNetworkRequestViewModel {
    let badgeColor: Color
    let status: String
    let title: String
    let text: String

    let showInConsole: (() -> Void)?

    private let message: LoggerMessageEntity
    private let request: LoggerNetworkRequestEntity
    private let context: AppContext

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    init(message: LoggerMessageEntity, request: LoggerNetworkRequestEntity, context: AppContext, showInConsole: (() -> Void)? = nil) {
        let isSuccess: Bool
        if request.errorCode != 0 {
            isSuccess = false
        } else if request.statusCode != 0, !(200..<400).contains(request.statusCode) {
            isSuccess = false
        } else {
            isSuccess = true
        }

        let time = ConsoleMessageViewModel.timeFormatter.string(from: request.createdAt)
        let prefix: String
        if request.statusCode != 0 {
            prefix = StatusCodeFormatter.string(for: Int(request.statusCode))
        } else if request.errorCode != 0 {
            prefix = "\(request.errorCode) (\(descriptionForURLErrorCode(Int(request.errorCode))))"
        } else {
            prefix = "Success"
        }

        self.status = prefix
        var title = "\(time)"
        if request.duration > 0 {
            title += " · \(DurationFormatter.string(from: request.duration))"
        }
        self.title = title

        let method = request.httpMethod ?? "GET"
        self.text = method + " " + (request.url ?? "–")

        self.badgeColor = isSuccess ? .green : .red

        self.request = request

        self.message = message
        self.context = context
        self.showInConsole = showInConsole
    }

    // MARK: Pins

    var isPinnedPublisher: AnyPublisher<Bool, Never> {
        message.publisher(for: \.isPinned).eraseToAnyPublisher()
    }

    var isPinned: Bool {
        message.isPinned
    }

    func togglePin() {
        context.store.togglePin(for: message)
    }

    // MARK: Context Menu

    var containsResponseData: Bool {
        request.responseBodyKey != nil
    }

    // WARNING: This call is relatively expensive.
    var responseString: String? {
        request.responseBodyKey
            .flatMap(context.store.getData)
            .flatMap { String(data: $0, encoding: .utf8) }
    }

    var url: String? {
        request.url
    }

    var host: String? {
        request.host
    }

    var cURLDescription: String {
        NetworkLoggerSummary(request: request, store: context.store).cURLDescription()
    }
}

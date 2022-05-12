// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import CoreData
import PulseCore
import Combine
import SwiftUI

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
final class ConsoleMessageDetailsViewModel {
    let tags: [ConsoleMessageTagViewModel]
    let text: String
    let badge: BadgeViewModel?

    private let message: LoggerMessageEntity
    private let store: LoggerStore

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        #if os(watchOS)
        formatter.dateFormat = "HH:mm:ss.SSS"
        #else
        formatter.dateFormat = "HH:mm:ss.SSS, yyyy-MM-dd"
        #endif
        return formatter
    }()

    init(store: LoggerStore, message: LoggerMessageEntity) {
        self.store = store
        self.message = message
        self.tags = message.metadata.reduce(into: [
            ConsoleMessageTagViewModel(
                title: "Date",
                value: ConsoleMessageDetailsViewModel.dateFormatter
                    .string(from: message.createdAt)
            ),
            ConsoleMessageTagViewModel(
                title: "Label",
                value: message.label
            )
        ]) {
            $0.append(.init(title: $1.key, value: $1.value))
        }

        self.text = message.text
        self.badge = BadgeViewModel(message: message)
    }

    func prepareForSharing() -> Any {
        return text
    }

    var pin: PinButtonViewModel {
        PinButtonViewModel(store: store, message: message)
    }
}

@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
private extension BadgeViewModel {
    init?(message: LoggerMessageEntity) {
        guard let level = LoggerStore.Level(rawValue: message.level) else { return nil }
        self.init(title: level.rawValue.uppercased(), color: Color(level: level))
    }
}

@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
private extension Color {
    init(level: LoggerStore.Level) {
        switch level {
        case .critical: self = .red
        case .error: self = .red
        case .warning: self = .orange
        case .info: self = .blue
        case .notice: self = .indigo
        case .debug: self = .secondaryFill
        case .trace: self = .secondaryFill
        }
    }
}

struct ConsoleMessageTagViewModel {
    let title: String
    let value: String
}

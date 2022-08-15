// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

final class ConsoleMessageDetailsViewModel {
    let textViewModel: RichTextViewModel

    let tags: [ConsoleMessageTagViewModel]
    let text: String
    let badge: BadgeViewModel?

    let message: LoggerMessageEntity

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        #if os(watchOS)
        formatter.dateFormat = "HH:mm:ss.SSS"
        #else
        formatter.dateFormat = "HH:mm:ss.SSS, yyyy-MM-dd"
        #endif
        return formatter
    }()

    init(message: LoggerMessageEntity) {
        self.textViewModel = RichTextViewModel(string: message.text)
        self.message = message
        self.tags = [
            ConsoleMessageTagViewModel(
                title: "Date",
                value: ConsoleMessageDetailsViewModel.dateFormatter
                    .string(from: message.createdAt)
            ),
            ConsoleMessageTagViewModel(title: "Label", value: message.label.name)
        ]
        self.text = message.text
        self.badge = BadgeViewModel(message: message)
    }

    func prepareForSharing() -> Any {
        text
    }

    var pin: PinButtonViewModel {
        PinButtonViewModel(message: message)
    }
}

private extension BadgeViewModel {
    init?(message: LoggerMessageEntity) {
        guard let level = LoggerStore.Level(rawValue: message.level) else { return nil }
        self.init(title: level.name.uppercased(), color: Color(level: level))
    }
}

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

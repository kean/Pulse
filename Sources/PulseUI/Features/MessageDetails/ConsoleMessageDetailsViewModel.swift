// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

final class ConsoleMessageDetailsViewModel {
    let textViewModel: RichTextViewModel

    let tags: [ConsoleMessageTagViewModel]
    let text: String
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
        let string = TextRenderer().preformatted(message.text)
        self.textViewModel = RichTextViewModel(string: string)

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
    }

    func prepareForSharing() -> Any {
        text
    }

    var pin: PinButtonViewModel {
        PinButtonViewModel(message: message)
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

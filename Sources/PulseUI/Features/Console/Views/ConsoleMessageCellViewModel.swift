// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

final class ConsoleMessageCellViewModel {
    let message: LoggerMessageEntity

    private let searchCriteriaViewModel: ConsoleSearchCriteriaViewModel?

    // TODO: Trim whitespaces and remove newlines?
    var preprocessedText: String { message.text }
    
    private(set) lazy var time = ConsoleMessageCellViewModel.timeFormatter.string(from: message.createdAt)

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    init(message: LoggerMessageEntity, searchCriteriaViewModel: ConsoleSearchCriteriaViewModel? = nil) {
        self.message = message
        self.searchCriteriaViewModel = searchCriteriaViewModel
    }
}

extension UXColor {
    static func textColor(for level: LoggerStore.Level) -> UXColor {
        switch level {
        case .trace: return .secondaryLabel
        case .debug, .info: return .label
        case .notice, .warning: return .systemOrange
        case .error, .critical: return .red
        }
    }
}

extension Color {
    static func textColor(for level: LoggerStore.Level) -> Color {
        switch level {
        case .trace: return .secondary
        case .debug, .info: return .primary
        case .notice, .warning: return .orange
        case .error, .critical: return .red
        }
    }
}

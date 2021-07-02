// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore
import CoreData
import Combine

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
final class ConsoleMessageViewModel {
    let title: String
    let text: String
    let textColor: Color
    let badge: BadgeViewModel?

    let showInConsole: (() -> Void)?

    private let objectID: NSManagedObjectID
    private let context: AppContext

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    init(message: LoggerMessageEntity, context: AppContext, showInConsole: (() -> Void)? = nil) {
        let time = ConsoleMessageViewModel.timeFormatter.string(from: message.createdAt)
        if message.label == "default" {
            self.title = time
        } else {
            self.title = "\(time) · \(message.label.capitalized)"
        }
        self.text = message.text
        self.textColor = ConsoleMessageStyle.textColor(level: LoggerStore.Level(rawValue: message.level) ?? .debug)
        self.badge = BadgeViewModel(message: message)
        self.context = context
        self.objectID = message.objectID
        self.showInConsole = showInConsole
    }

    // MARK: Pins

    var isPinnedPublisher: AnyPublisher<Bool, Never> {
        context.pins.isPinnedMessageWithID(objectID)
    }

    var isPinned: Bool {
        context.pins.pins.contains(objectID)
    }

    func togglePin() {
        context.pins.togglePinWithID(objectID)
    }
}

@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
private extension BadgeViewModel {
    init?(message: LoggerMessageEntity) {
        guard let model = LoggerStore.Level(rawValue: message.level).flatMap(BadgeViewModel.init) else {
            return nil
        }
        self = model
    }

    init?(level: LoggerStore.Level) {
        switch level {
        case .critical: self.init(title: "CRITICAL", color: .red)
        case .error: self.init(title: "ERROR", color: .red)
        case .warning: self.init(title: "WARNING", color: .orange)
        case .info: self.init(title: "INFO", color: .blue)
        case .notice: self.init(title: "NOTICE", color: .indigo)
        case .debug: return nil
        case .trace: return nil
        }
    }
}

@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
extension Color {
    static func textColor(for level: LoggerStore.Level) -> Color {
        switch level {
        case .critical: return .red
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .notice: return .blue
        case .debug: return .primary
        case .trace: return .primary
        }
    }
}

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
enum ConsoleMessageStyle {
    static func textColor(level: LoggerStore.Level) -> Color {
        switch level {
        case .trace: return .primary
        case .debug: return .primary
        case .info: return .primary
        case .notice: return .orange
        case .warning: return .orange
        case .error: return .red
        case .critical: return .red
        }
    }
}

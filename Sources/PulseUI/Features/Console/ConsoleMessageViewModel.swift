// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

final class ConsoleMessageViewModel: Pinnable {
    let title: String
    let text: String
    let textColor: Color
    let badge: BadgeViewModel?
    
    private let message: LoggerMessageEntity
    private let searchCriteriaViewModel: ConsoleSearchCriteriaViewModel?
    
    private(set) lazy var time = ConsoleMessageViewModel.timeFormatter.string(from: message.createdAt)
    
#if os(iOS)
    lazy var textColor2 = UIColor.textColor(for: LoggerStore.Level(rawValue: message.level) ?? .debug)
    lazy var attributedTitle: NSAttributedString = {
        let string = NSMutableAttributedString()
        let level = LoggerStore.Level(rawValue: message.level) ?? .debug
        if let badge = badge {
            string.append(badge.title, [.foregroundColor: UIColor.badgeColor(for: level)])
        }
        if message.label.name != "default" {
            let prefix = badge == nil ? "" : " · "
            string.append("\(prefix)\(message.label.name.capitalized)", [.foregroundColor: UIColor.secondaryLabel])
        }
        return string
    }()
#endif
    
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    private(set) lazy var pinViewModel = PinButtonViewModel(message: message)
    
    init(message: LoggerMessageEntity, searchCriteriaViewModel: ConsoleSearchCriteriaViewModel? = nil) {
        let time = ConsoleMessageViewModel.timeFormatter.string(from: message.createdAt)
        if message.label.name == "default" {
            self.title = time
        } else {
            self.title = "\(time) · \(message.label.name.capitalized)"
        }
        self.text = message.text
        self.textColor = ConsoleMessageStyle.textColor(level: LoggerStore.Level(rawValue: message.level) ?? .debug)
        self.badge = BadgeViewModel(message: message)
        self.message = message
        self.searchCriteriaViewModel = searchCriteriaViewModel
    }
    
    // MARK: Context Menu

#if os(iOS) || os(macOS)
    func share() -> ShareItems {
        ShareItems([ConsoleShareService.share(message)])
    }
    
    func copy() -> String {
        message.text
    }
    
    var focusLabel: String {
        message.label.name.capitalized
    }
    
    func focus() {
        searchCriteriaViewModel?.criteria.labels.isEnabled = true
        searchCriteriaViewModel?.criteria.labels.focused = message.label.name
    }
    
    func hide() {
        searchCriteriaViewModel?.criteria.labels.isEnabled = true
        searchCriteriaViewModel?.criteria.labels.hidden.insert(message.label.name)
    }
#endif
}

private extension BadgeViewModel {
    init?(message: LoggerMessageEntity) {
        guard let model = LoggerStore.Level(rawValue: message.level).flatMap(BadgeViewModel.init) else {
            return nil
        }
        self = model
    }
    
    init?(level: LoggerStore.Level) {
        switch level {
        case .critical, .error, .warning, .info, .notice:
            self.init(title: level.name.uppercased(), color: .badgeColor(for: level))
        case .debug, .trace:
            return nil // Don't show
        }
    }
}

extension Color {
    static func badgeColor(for level: LoggerStore.Level) -> Color {
        switch level {
#if os(macOS)
        case .error: return Color(Palette.red)
        case .critical: return Color(Palette.red)
#else
        case .critical: return .red
        case .error: return .red
#endif
        case .warning: return .orange
        case .info: return .blue
        case .notice: return .indigo
        case .debug: return .primary
        case .trace: return .primary
        }
    }
    
    static func textColor(for level: LoggerStore.Level) -> Color {
        switch level {
#if os(macOS)
        case .error: return Color(Palette.red)
        case .critical: return Color(Palette.red)
#else
        case .critical: return .red
        case .error: return .red
#endif
        case .warning: return .orange
        case .info: return .blue
        case .notice: return .blue
        case .debug: return .primary
        case .trace: return .primary
        }
    }
}

#if os(iOS)
extension UIColor {
    static func badgeColor(for level: LoggerStore.Level) -> UIColor {
        switch level {
        case .critical: return .systemRed
        case .error: return .systemRed
        case .warning: return .systemOrange
        case .info: return .systemBlue
        case .notice: return .systemBlue
        case .debug: return .label
        case .trace: return .label
        }
    }
    
    static func textColor(for level: LoggerStore.Level) -> UIColor {
        switch level {
        case .trace: return .secondaryLabel
        case .debug, .info: return .label
        case .notice, .warning: return .systemOrange
        case .error, .critical: return .systemRed
        }
    }
}
#endif

#if os(macOS)
enum ConsoleMessageStyle {
    static func textColor(level: LoggerStore.Level) -> Color {
        switch level {
        case .trace: return .secondary
        case .debug: return .primary
        case .info: return .primary
        case .notice: return .orange
        case .warning: return .orange
        case .error: return Color(Palette.red)
        case .critical: return Color(Palette.red)
        }
    }
}
#else
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
#endif

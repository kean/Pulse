// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

#warning("TODO: refactor")
final class ConsoleMessageViewModel: Pinnable {
    let title: String
    let text: String
    let textColor: Color
    let level: String

    let message: LoggerMessageEntity
    private let searchCriteriaViewModel: ConsoleMessageSearchCriteriaViewModel?
    
    private(set) lazy var time = ConsoleMessageViewModel.timeFormatter.string(from: message.createdAt)

    var titleForTextRepresentation: String {
        let level = message.logLevel
        var title = "\(time) · \(level.name.capitalized)"
        let label = message.label.name
        if label != "default", !label.isEmpty {
            title.append(" · \(label.capitalized)")
        }
        return title
    }

#if os(iOS)
    lazy var textColor2 = UIColor.textColor(for: message.logLevel)
    lazy var title2: String = {
        var string = message.logLevel.name.uppercased()
        let label = message.label.name
        if label != "default", !label.isEmpty {
            string.append(" · \(label.capitalized)")
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
    
    init(message: LoggerMessageEntity, searchCriteriaViewModel: ConsoleMessageSearchCriteriaViewModel? = nil) {
        let time = ConsoleMessageViewModel.timeFormatter.string(from: message.createdAt)
        if message.label.name == "default" || message.label.name.isEmpty {
            self.title = time
        } else {
            self.title = "\(time) · \(message.label.name.capitalized)"
        }
        self.text = message.text
        self.textColor = .textColor(for: message.logLevel)
        self.message = message
        self.level = message.logLevel.name.uppercased()
        self.searchCriteriaViewModel = searchCriteriaViewModel
    }
    
    // MARK: Context Menu

#if os(iOS) || os(macOS)
    func share() -> ShareItems {
        ShareItems([message.text])
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

extension UXColor {
    static func textColor(for level: LoggerStore.Level) -> UXColor {
        switch level {
        case .trace: return .secondaryLabel
        case .debug, .info: return .label
        case .notice, .warning: return .systemOrange
#if os(macOS)
        case .error, .critical: return Palette.red
#else
        case .error, .critical: return .red
#endif
        }
    }
}

extension Color {
    static func textColor(for level: LoggerStore.Level) -> Color {
        switch level {
        case .trace: return .secondary
        case .debug, .info: return .primary
        case .notice, .warning: return .orange
#if os(macOS)
        case .error, .critical: return Color(Palette.red)
#else
        case .error, .critical: return .red
#endif
        }
    }
}

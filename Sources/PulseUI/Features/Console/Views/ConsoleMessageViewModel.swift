// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

final class ConsoleMessageViewModel: Pinnable {
    let message: LoggerMessageEntity

    private let searchViewModel: ConsoleSearchViewModel?

    // TODO: Trim whitespaces and remove newlines?
    var preprocessedText: String { message.text }
    
    private(set) lazy var time = ConsoleMessageViewModel.timeFormatter.string(from: message.createdAt)

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    private(set) lazy var pinViewModel = PinButtonViewModel(message: message)
    
    init(message: LoggerMessageEntity, searchViewModel: ConsoleSearchViewModel? = nil) {
        self.message = message
        self.searchViewModel = searchViewModel
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
        searchViewModel?.criteria.messages.labels.isEnabled = true
        searchViewModel?.criteria.messages.labels.focused = message.label.name
    }
    
    func hide() {
        searchViewModel?.criteria.messages.labels.isEnabled = true
        searchViewModel?.criteria.messages.labels.hidden.insert(message.label.name)
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

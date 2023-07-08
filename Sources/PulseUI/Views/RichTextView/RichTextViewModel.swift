// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import Pulse
import Combine

final class RichTextViewModel: ObservableObject {
    // Search
    @Published var searchOptions: StringSearchOptions = .default
    @Published private(set) var selectedMatchIndex: Int = 0
    @Published private(set) var matches: [SearchMatch] = []
    @Published var searchTerm: String = ""
    @Published var filterTerm: String = ""

    // Configuration
    @Published var isLinkDetectionEnabled = true
    var isLineNumberRulerEnabled = false
    var isFilterEnabled = false
    var isToolbarHidden = false

    let contentType: NetworkLogger.ContentType?
    let originalText: NSAttributedString

    var onLinkTapped: ((URL) -> Bool)?

    var isEmpty: Bool { originalText.length == 0 }

    weak var textView: UXTextView? // Not proper MVVM
    var textStorage: NSTextStorage { textView?.textStorage ?? NSTextStorage(string: "") }

    private var prefilteredText: NSAttributedString?
    private var isSearchingInBackground = false
    private var isSearchNeeded = false
    private let queue = DispatchQueue(label: "com.github.kean.pulse.search")
    private let settings = UserSettings.shared
    private var cancellables = [AnyCancellable]()

    struct SearchMatch {
        let range: NSRange
        let originalForegroundColor: UXColor
    }

    convenience init(string: NSAttributedString = NSAttributedString()) {
        self.init(string: string, contentType: nil)
    }

    init(string: NSAttributedString, contentType: NetworkLogger.ContentType?) {
        self.originalText = string
        self.contentType = contentType

        Publishers.CombineLatest3($searchTerm, $searchOptions, $filterTerm)
            .dropFirst()
            .receive(on: DispatchQueue.main) // Make sure self returns new values
            .sink { [weak self] _, _, _ in
                self?.setSearchNeeded()
            }.store(in: &cancellables)
    }

    func prepare(_ context: SearchContext?) {
        guard let context = context else { return }

        // Not updated self.searchTerm because searchable doesn't like that
        let matches = search(searchTerm: context.searchTerm.text, in: textStorage.string as NSString, options: context.searchTerm.options)
        didUpdateMatches(matches, string: textStorage)
        if context.matchIndex < matches.count {
            DispatchQueue.main.async {
#if os(iOS)
                self.textView?.layoutManager.allowsNonContiguousLayout = false // Remove this workaround
                UIView.performWithoutAnimation {
                    self.updateMatchIndex(context.matchIndex)
                }
#else
                self.updateMatchIndex(context.matchIndex)
#endif
            }
        }
    }

    func display(_ text: NSAttributedString) {
        matches.removeAll()
        textStorage.setAttributedString(text)
        searchTerm = ""
    }

    func performUpdates(_ closure: (NSTextStorage) -> Void) {
        textStorage.beginEditing()
        closure(textStorage)
        textStorage.endEditing()
    }

    private func setSearchNeeded() {
        isSearchNeeded = true
        searchIfNeeded()
    }

    private func searchIfNeeded() {
        guard isSearchNeeded && !isSearchingInBackground else { return }
        isSearchingInBackground = true
        isSearchNeeded = false

        var string = prefilteredText ?? NSAttributedString(attributedString: textStorage)
        let (searchTerm, filterTerm, options) = (searchTerm, filterTerm, searchOptions)

        if filterTerm.isEmpty {
            prefilteredText = nil
        } else {
            if prefilteredText == nil {
                prefilteredText = string
            }
        }

        queue.async {
            if !filterTerm.isEmpty {
                var hasMatch = false
                let output = NSMutableAttributedString()
                for line in string.getLines() {
                    if line.string.firstRange(of: filterTerm, options: .init(options)) != nil {
                        if hasMatch {
                            output.append("\n")
                        }
                        hasMatch = true
                        output.append(line)
                    }
                }
                string = output
            }

            let matches = search(searchTerm: searchTerm, in: string.string as NSString, options: options)
            DispatchQueue.main.async {
                self.didUpdateMatches(matches, string: string)
            }
        }
    }

    private func didUpdateMatches(_ newMatches: [NSRange], string: NSAttributedString) {
        performUpdates { _ in
            clearMatches()

            if string.length != textStorage.length {
                textStorage.setAttributedString(string)
            }

            matches = newMatches.filter {
                textStorage.attributes(at: $0.location, effectiveRange: nil)[.isTechnical] == nil
            }.map {
                let color = textStorage.attribute(.foregroundColor, at: $0.location, effectiveRange: nil) as? UXColor
                return SearchMatch(range: $0, originalForegroundColor: color ?? .label)
            }

            for match in matches {
                highlight(range: match.range)
            }
        }

        selectedMatchIndex = 0
        didUpdateCurrentSelectedMatch()
#if os(macOS)
        textView?.enclosingScrollView?.verticalRulerView?.needsDisplay = true
#endif

        isSearchingInBackground = false
        searchIfNeeded()
    }

    func nextMatch() {
        guard !matches.isEmpty else { return }
        updateMatchIndex(selectedMatchIndex + 1 < matches.count ? selectedMatchIndex + 1 : 0)
    }

    func previousMatch() {
        guard !matches.isEmpty else { return }
        updateMatchIndex(selectedMatchIndex - 1 < 0 ? matches.count - 1 : selectedMatchIndex - 1)
    }

    func updateMatchIndex(_ newIndex: Int) {
        let previousIndex = selectedMatchIndex
        selectedMatchIndex = newIndex
        didUpdateCurrentSelectedMatch(previousMatch: previousIndex)
    }

    private func didUpdateCurrentSelectedMatch(previousMatch: Int? = nil) {
        guard !matches.isEmpty else { return }

        // Scroll to visible range
        // Make sure it's somewhere in the middle (find newlines)
        var range = matches[selectedMatchIndex].range
        var index = range.upperBound
        var newlines = 0
        let string = textStorage.string as NSString
        while index < textStorage.length {
            if let character = Character(string.character(at: index)), character.isNewline {
                newlines += 1
                range.length += index - range.upperBound
                if newlines == 8 {
                    break
                }
            }
            index += 1
        }
        if let textView = textView {
            textView.scrollRangeToVisible(range)
        }
        // Update highlights
        if let previousMatch = previousMatch {
            highlight(range: matches[previousMatch].range)
        }
        highlight(range: matches[selectedMatchIndex].range, isFocused: true)

#if os(macOS)
        // A workaround for macOS where it doesn't always redraw itself correctly
        textView?.setNeedsDisplay(textView?.bounds ?? .zero)
#endif
    }

    private func clearMatches() {
        for match in matches {
            let range = match.range
#if os(macOS)
            textStorage.addAttribute(.foregroundColor, value: match.originalForegroundColor, range: range)
            textStorage.removeAttribute(.underlineStyle, range: range)
#else
            textStorage.addAttribute(.foregroundColor, value: match.originalForegroundColor, range: range)
            textStorage.removeAttribute(.backgroundColor, range: range)
#endif
        }
    }

    private func highlight(range: NSRange, isFocused: Bool = false) {
#if PULSE_STANDALONE_APP
        let style: RichTextViewUnderlyingStyle = isFocused ? .searchResultHighlighted : .searchResult
        textStorage.addAttributes([
            .underlineStyle: style.rawValue,
            .foregroundColor: isFocused ? UXColor.black : UXColor.textColor
        ], range: range)
#else
        textStorage.addAttributes([
            .backgroundColor: UXColor.systemBlue.withAlphaComponent(isFocused ? 0.8 : 0.3),
            .foregroundColor: UXColor.white
        ], range: range)
#endif
    }
}

private func search(searchTerm: String, in string: NSString, options: StringSearchOptions) -> [NSRange] {
    guard searchTerm.count >= 1 else {
        return []
    }
    return string.ranges(of: searchTerm, options: options)
}

#endif

extension RichTextViewModel {
    struct SearchContext {
        let searchTerm: ConsoleSearchTerm
        let matchIndex: Int
    }
}

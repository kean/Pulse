// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

#if os(iOS) || os(visionOS)

public final class RichTextViewModel: ObservableObject {
    // Search
    @Published var searchOptions: StringSearchOptions = .default
    @Published private(set) var selectedMatchIndex: Int = 0
    @Published private(set) var matches: [SearchMatch] = []
    @Published var searchTerm: String = ""

    // Configuration
    @Published public var isLinkDetectionEnabled = true
    var isToolbarHidden = false

    public let contentType: NetworkLogger.ContentType?
    public let originalText: NSAttributedString

    public var onLinkTapped: ((URL) -> Bool)?

    public var isEmpty: Bool { originalText.length == 0 }

    weak var textView: UXTextView? // Not proper MVVM
    var textStorage: NSTextStorage { textView?.textStorage ?? NSTextStorage(string: "") }

    private var isSearchingInBackground = false
    private var isSearchNeeded = false
    private let queue = DispatchQueue(label: "com.github.kean.pulse.search")
    private let settings = UserSettings.shared
    private var cancellables = [AnyCancellable]()

    struct SearchMatch {
        let range: NSRange
        let originalForegroundColor: UXColor
        let originalBackgroundColor: UXColor?
    }

    public convenience init(string: NSAttributedString = NSAttributedString()) {
        self.init(string: string, contentType: nil)
    }

    public init(string: NSAttributedString, contentType: NetworkLogger.ContentType?) {
        self.originalText = string
        self.contentType = contentType

        Publishers.CombineLatest($searchTerm, $searchOptions)
            .dropFirst()
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.setSearchNeeded()
            }.store(in: &cancellables)
    }

    func prepare(_ context: TextViewSearchContext?) {
        guard let context = context else { return }

        // Not updated self.searchTerm because searchable doesn't like that
        let matches = search(searchTerm: context.searchTerm.text, in: originalText, options: context.searchTerm.options)
        didUpdateMatches(matches, string: textStorage)
        if context.matchIndex < matches.count {
            DispatchQueue.main.async {
                self.textView?.layoutManager.allowsNonContiguousLayout = false // Remove this workaround
                UIView.performWithoutAnimation {
                    self.updateMatchIndex(context.matchIndex)
                }
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

        let string = textStorage
        let (searchTerm, options) = (searchTerm, searchOptions)
        let originalText = self.originalText

        queue.async {
            let matches = search(searchTerm: searchTerm, in: originalText, options: options)
            DispatchQueue.main.async {
                self.didUpdateMatches(matches, string: string)
            }
        }
    }

    private func didUpdateMatches(_ newMatches: [SearchMatch], string: NSAttributedString) {
        performUpdates { _ in
            clearMatches()

            if string.length != textStorage.length {
                textStorage.setAttributedString(string)
            }

            matches = newMatches

            for match in matches {
                highlight(range: match.range)
            }
        }

        selectedMatchIndex = 0
        didUpdateCurrentSelectedMatch()
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

        // Scroll to a slightly extended range so the match isn't pinned to the
        // top edge. Use native newline search instead of a per-character loop.
        var range = matches[selectedMatchIndex].range
        let string = textStorage.string as NSString
        var searchStart = range.upperBound
        for _ in 0..<8 {
            guard searchStart < string.length else { break }
            let found = string.range(of: "\n", options: [], range: NSRange(location: searchStart, length: string.length - searchStart))
            if found.location == NSNotFound { break }
            range.length = found.location - range.location
            searchStart = found.upperBound
        }
        textView?.scrollRangeToVisible(range)

        // Update highlights
        if let previousMatch = previousMatch {
            highlight(range: matches[previousMatch].range)
        }
        highlight(range: matches[selectedMatchIndex].range, isFocused: true)
    }

    private func clearMatches() {
        for match in matches {
            let range = match.range
            textStorage.addAttribute(.foregroundColor, value: match.originalForegroundColor, range: range)
            textStorage.removeAttribute(.backgroundColor, range: range)
            if let backgroundColor = match.originalBackgroundColor {
                textStorage.addAttribute(.backgroundColor, value: backgroundColor, range: range)
            }
        }
    }

    private func highlight(range: NSRange, isFocused: Bool = false) {
        textStorage.addAttributes([
            .backgroundColor: UXColor.systemBlue.withAlphaComponent(isFocused ? 0.8 : 0.3),
            .foregroundColor: UXColor.white
        ], range: range)
    }
}

/// Runs on a background queue. We resolve match metadata (technical-attribute filter
/// and the original colors used by `clearMatches`) from the immutable `originalText`
/// here, so the main-thread work in `didUpdateMatches` is just applying highlights.
private func search(searchTerm: String, in originalText: NSAttributedString, options: StringSearchOptions) -> [RichTextViewModel.SearchMatch] {
    guard searchTerm.count >= 1 else {
        return []
    }
    let ranges = (originalText.string as NSString).ranges(of: searchTerm, options: options)
    return ranges.compactMap { range -> RichTextViewModel.SearchMatch? in
        guard range.location < originalText.length else { return nil }
        let attributes = originalText.attributes(at: range.location, effectiveRange: nil)
        guard attributes[.isTechnical] == nil else { return nil }
        let foreground = attributes[.foregroundColor] as? UXColor
        let background = attributes[.backgroundColor] as? UXColor
        return RichTextViewModel.SearchMatch(
            range: range,
            originalForegroundColor: foreground ?? .label,
            originalBackgroundColor: background
        )
    }
}

#endif

private struct TextViewSearchContextKey: EnvironmentKey {
    static var defaultValue: TextViewSearchContext?
}

extension EnvironmentValues {
    package var textViewSearchContext: TextViewSearchContext? {
        get { self[TextViewSearchContextKey.self] }
        set { self[TextViewSearchContextKey.self] = newValue }
    }
}

package struct TextViewSearchContext {
    package let searchTerm: ConsoleSearchTerm
    package let matchIndex: Int

    package init(searchTerm: ConsoleSearchTerm, matchIndex: Int) {
        self.searchTerm = searchTerm
        self.matchIndex = matchIndex
    }
}

#if os(watchOS) || os(tvOS) || os(macOS)
public final class RichTextViewModel: ObservableObject {
    public let text: String
    public let attributedString: AttributedString?

    public var isLinkDetectionEnabled = true
    public var isEmpty: Bool { text.isEmpty }

    public init(string: String) {
        self.text = string
        self.attributedString = nil
    }

    public init(string: NSAttributedString, contentType: NetworkLogger.ContentType? = nil) {
#if os(macOS)
        self.attributedString = try? AttributedString(string, including: \.appKit)
#else
        self.attributedString = try? AttributedString(string, including: \.uiKit)
#endif
        self.text = string.string
    }
}
#endif

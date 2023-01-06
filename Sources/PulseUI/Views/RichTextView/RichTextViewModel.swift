// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

final class RichTextViewModel: ObservableObject {
    // Search
    @Published var searchOptions: StringSearchOptions = .default
    @Published private(set) var selectedMatchIndex: Int = 0
    @Published private(set) var matches: [Range<String.Index>] = []
    @Published var isSearching = false
    @Published var searchTerm: String = ""

    // Configureion
    @Published var isLinkDetectionEnabled = true

    var error: NetworkLogger.DecodingError?
    var onLinkTapped: ((URL) -> Bool)?
    let contentType: NetworkLogger.ContentType?

    private(set) var text: NSAttributedString
    private var string: String
    var isEmpty: Bool { string.isEmpty }

    weak var textView: UXTextView? // Not proper MVVM
    var textStorage: NSTextStorage { textView?.textStorage ?? NSTextStorage(string: "") }

    private var bag = [AnyCancellable]()

    convenience init(string: String = "") {
        self.init(string: TextRenderer().render(string, role: .body2))
    }

    convenience init(string: NSAttributedString) {
        self.init(string: string, contentType: nil)
    }

#warning("TODO: we shouldn't need content type here")
    init(string: NSAttributedString, contentType: NetworkLogger.ContentType?) {
        self.text = string
        self.string = string.string
        self.contentType = contentType

        Publishers.CombineLatest($searchTerm, $searchOptions).sink { [weak self] in
            self?.refresh(searchTerm: $0, options: $1)
        }.store(in: &bag)
    }

    func display(_ text: NSAttributedString) {
        self.text = text
        self.string = text.string
        self.matches.removeAll()

        let textStorage: NSTextStorage? = textView?.textStorage
        textStorage?.setAttributedString(text)
        searchTerm = ""
    }

    func performUpdates(_ closure: (NSTextStorage) -> Void) {
        textStorage.beginEditing()
        closure(textStorage)
        textStorage.endEditing()
    }

#warning("TODO: perform search in the background")
    private func refresh(searchTerm: String, options: StringSearchOptions) {
#warning("TODO: implemet search using NSString API to work with emoji properl")
        let newMatches = search(searchTerm: searchTerm, options: options)

        performUpdates { _ in
            clearMatches()
            matches = newMatches
            for match in matches {
                highlight(range: match)
            }
        }

#warning("TODO: should keep current index if possible")
        selectedMatchIndex = 0

        didUpdateCurrentSelectedMatch()
    }

    func search(searchTerm: String, options: StringSearchOptions) -> [Range<String.Index>] {
        guard searchTerm.count > 1 else {
            return []
        }
        return string.ranges(of: searchTerm, options: .init(options))
    }

    func cancelSearch() {
        searchTerm = ""
        isSearching = false
        hideKeyboard()
    }

    func nextMatch() {
        guard !matches.isEmpty else { return }
        updateMatchIndex(selectedMatchIndex + 1 < matches.count ? selectedMatchIndex + 1 : 0)
    }

    func previousMatch() {
        guard !matches.isEmpty else { return }
        updateMatchIndex(selectedMatchIndex - 1 < 0 ? matches.count - 1 : selectedMatchIndex - 1)
    }

    private func updateMatchIndex(_ newIndex: Int) {
        let previousIndex = selectedMatchIndex
        selectedMatchIndex = newIndex
        didUpdateCurrentSelectedMatch(previousMatch: previousIndex)
    }

    private func didUpdateCurrentSelectedMatch(previousMatch: Int? = nil) {
        guard !matches.isEmpty else { return }

        // Scroll to visible range
        var range = NSRange(matches[selectedMatchIndex], in: string)
        if range.length + 50 < string.count {
            range.length += 50
        }
        if let textView = textView {
            textView.scrollRangeToVisible(range)
        }
        // Update highlights
        if let previousMatch = previousMatch {
            highlight(range: matches[previousMatch])
        }
        highlight(range: matches[selectedMatchIndex], isFocused: true)
    }

    private func clearMatches() {
        for match in matches {
            let range = NSRange(match, in: string)
            textStorage.removeAttribute(.foregroundColor, range: range)
            if let originalForegroundColor = text.attribute(.foregroundColor, at: range.lowerBound, effectiveRange: nil) {
                textStorage.addAttribute(.foregroundColor, value: originalForegroundColor, range: range)
            }
            textStorage.removeAttribute(.backgroundColor, range: range)
        }
    }

    private func highlight(range: Range<String.Index>, isFocused: Bool = false) {
        let range = NSRange(range, in: text.string)
        textStorage.addAttributes([
            .backgroundColor: UXColor.systemBlue.withAlphaComponent(isFocused ? 0.8 : 0.3),
            .foregroundColor: UXColor.white
        ], range: range)
    }
}

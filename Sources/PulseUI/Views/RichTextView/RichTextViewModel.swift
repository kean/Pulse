// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS) || os(macOS)

final class RichTextViewModel: ObservableObject {
    // Search
    @Published var searchOptions: StringSearchOptions = .default
    @Published private(set) var selectedMatchIndex: Int = 0
    @Published private(set) var matches: [NSRange] = []
    @Published var isSearching = false
    @Published var searchTerm: String = ""

    // Configureion
    @Published var isLinkDetectionEnabled = true

    var error: NetworkLogger.DecodingError?
    var onLinkTapped: ((URL) -> Bool)?
    let contentType: NetworkLogger.ContentType?

    private(set) var text: NSAttributedString
    var isEmpty: Bool { text.length == 0 }

    weak var textView: UXTextView? // Not proper MVVM
    var textStorage: NSTextStorage { textView?.textStorage ?? NSTextStorage(string: "") }

    private var isSearchingInBackground = false
    private var isSearchNeeded = false
    private let queue = DispatchQueue(label: "com.github.kean.pulse.search")
    private let settings = ConsoleSettings.shared
    private var bag = [AnyCancellable]()

    convenience init(string: String = "") {
        self.init(string: TextRenderer().render(string, role: .body2))
    }

    convenience init(string: NSAttributedString) {
        self.init(string: string, contentType: nil)
    }

    init(string: NSAttributedString, contentType: NetworkLogger.ContentType?) {
        self.text = string
        self.contentType = contentType

        Publishers.CombineLatest($searchTerm, $searchOptions)
            .dropFirst()
            .receive(on: DispatchQueue.main) // Make sure self returns new values
            .sink { [weak self] _, _ in
                self?.setSearchNeeded()
            }.store(in: &bag)
    }

    func display(_ text: NSAttributedString) {
        self.text = text
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

    private func setSearchNeeded() {
        isSearchNeeded = true
        searchIfNeeded()
    }

    private func searchIfNeeded() {
        guard isSearchNeeded && !isSearchingInBackground else { return }
        isSearchingInBackground = true
        isSearchNeeded = false

        let string = textStorage.string as NSString
        let (term, options) = (searchTerm, searchOptions)
        queue.async {
            let matches = search(searchTerm: term, in: string, options: options)
            DispatchQueue.main.async {
                self.didUpdateMatches(matches)
            }
        }
    }

    private func didUpdateMatches(_ newMatches: [NSRange]) {
        let newMatches = newMatches.filter {
            textStorage.attributes(at: $0.location, effectiveRange: nil)[.isTechnical] == nil
        }

        performUpdates { _ in
            clearMatches()
            matches = newMatches
            for match in matches {
                highlight(range: match)
            }
        }

        selectedMatchIndex = 0
        didUpdateCurrentSelectedMatch()

        isSearchingInBackground = false
        searchIfNeeded()
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
        var range = matches[selectedMatchIndex]
        if range.length + 50 < textStorage.length {
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
        for range in matches {
            textStorage.removeAttribute(.foregroundColor, range: range)
            if let originalForegroundColor = text.attribute(.foregroundColor, at: range.lowerBound, effectiveRange: nil) {
                textStorage.addAttribute(.foregroundColor, value: originalForegroundColor, range: range)
            }
            textStorage.removeAttribute(.backgroundColor, range: range)
        }
    }

    private func highlight(range: NSRange, isFocused: Bool = false) {
        textStorage.addAttributes([
            .backgroundColor: UXColor.systemBlue.withAlphaComponent(isFocused ? 0.8 : 0.3),
            .foregroundColor: UXColor.white
        ], range: range)
    }
}

private func search(searchTerm: String, in string: NSString, options: StringSearchOptions) -> [NSRange] {
    guard searchTerm.count > 1 else {
        return []
    }
    return string.ranges(of: searchTerm, options: .init(options))
}

#endif

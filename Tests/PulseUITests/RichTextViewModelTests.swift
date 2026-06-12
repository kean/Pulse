// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS)

@testable import PulseUI
import Testing
import UIKit

@Suite("RichTextViewModel")
struct RichTextViewModelTests {
    @Test("Search highlights matches when text storage is unchanged")
    @MainActor
    func searchHighlightsMatchesWhenTextStorageIsUnchanged() async throws {
        let (viewModel, _) = makeViewModel(string: "needle padding needle")

        viewModel.searchTerm = "needle"

        try await waitForSearch()

        #expect(viewModel.matches.count == 2)
        #expect(viewModel.selectedMatchIndex == 0)
    }

    @Test("Search clears stale matches after text storage changes")
    @MainActor
    func searchClearsStaleMatchesAfterTextStorageChanges() async throws {
        let (viewModel, textView) = makeViewModel(
            string: String(repeating: "needle padding\n", count: 1_000)
        )

        viewModel.searchTerm = "needle"
        try await waitForSearch()
        #expect(!viewModel.matches.isEmpty)

        textView.textStorage.setAttributedString(NSAttributedString(string: "short"))
        viewModel.searchTerm = "padding"

        try await waitForSearch()

        #expect(viewModel.matches.isEmpty)
    }

    @Test("Search ignores stale matches when text storage changes")
    @MainActor
    func searchIgnoresStaleMatchesWhenTextStorageChanges() async throws {
        let originalText = NSAttributedString(
            string: String(repeating: "needle padding\n", count: 1_000)
        )
        let viewModel = RichTextViewModel(string: originalText, contentType: nil)

        let textView = UITextView()
        textView.attributedText = NSAttributedString(string: "short")
        viewModel.textView = textView

        viewModel.searchTerm = "needle"

        try await waitForSearch()

        #expect(viewModel.matches.isEmpty)
    }

    @Test("Selecting match ignores stale range when text storage changes")
    @MainActor
    func selectingMatchIgnoresStaleRangeWhenTextStorageChanges() async throws {
        let (viewModel, textView) = makeViewModel(string: "needle padding needle")

        viewModel.searchTerm = "needle"
        try await waitForSearch()
        #expect(viewModel.matches.count == 2)

        textView.textStorage.setAttributedString(NSAttributedString(string: "short"))
        viewModel.updateMatchIndex(0)

        #expect(viewModel.selectedMatchIndex == 0)
    }

    @Test("Can move between matches when ranges are valid")
    @MainActor
    func canMoveBetweenMatchesWhenRangesAreValid() async throws {
        let (viewModel, _) = makeViewModel(string: "needle padding needle")

        viewModel.searchTerm = "needle"
        try await waitForSearch()
        #expect(viewModel.matches.count == 2)

        viewModel.updateMatchIndex(1)

        #expect(viewModel.selectedMatchIndex == 1)
    }
}

@MainActor
private func makeViewModel(string: String) -> (RichTextViewModel, UITextView) {
    let text = NSAttributedString(string: string)
    let viewModel = RichTextViewModel(string: text, contentType: nil)
    let textView = UITextView()
    textView.attributedText = text
    viewModel.textView = textView
    return (viewModel, textView)
}

private func waitForSearch() async throws {
    try await Task.sleep(nanoseconds: 500_000_000)
}

#endif

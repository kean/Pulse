// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(macOS) || os(iOS)

struct RichTextView<ExtraMenu: View>: View {
    @ObservedObject private var viewModel: RichTextViewModel
    @State private var isExpanded = false
    @State private var isScrolled = false
    @State private var errorViewOpacity = 0.0
    var isAutomaticLinkDetectionEnabled = true
    var hasVerticalScroller = false
    var onToggleExpanded: (() -> Void)?
    @ViewBuilder var extraMenu: () -> ExtraMenu

    init(viewModel: RichTextViewModel,
         isAutomaticLinkDetectionEnabled: Bool = true,
         hasVerticalScroller: Bool = true,
         onToggleExpanded: (() -> Void)? = nil,
         @ViewBuilder extraMenu: @escaping () -> ExtraMenu) {
        self.viewModel = viewModel
        self.isAutomaticLinkDetectionEnabled = isAutomaticLinkDetectionEnabled
        self.hasVerticalScroller = hasVerticalScroller
        self.onToggleExpanded = onToggleExpanded
        self.extraMenu = extraMenu
    }
#if os(iOS)
    var body: some View {
        VStack(spacing: 0) {
            searchToolbar
                .backport.backgroundThickMaterial(enabled: isExpanded && isScrolled)
            ZStack(alignment: .bottom) {
                textView
                    .edgesIgnoringSafeArea(.bottom)
                errorView
            }
            if viewModel.isSearching {
                SearchToobar(viewModel: viewModel)
            }
        }
        .onAppear(perform: onAppear)
    }

    private var searchToolbar: some View {
        HStack(spacing: 0) {
            SearchBar(title: "Search", text: $viewModel.searchTerm, onEditingChanged: { isEditing in
                if isEditing {
                    viewModel.isSearching = isEditing
                }
            })

            if #available(iOS 14.0, *) {
                Menu(content: {
                    StringSearchOptionsMenu(options: $viewModel.options, isKindNeeded: false)
                    let extraMenu = self.extraMenu()
                    if !(extraMenu is EmptyView) {
                        extraMenu
                    }
                }, label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .frame(width: 40, height: 44)
                })
            }
            if let onToggleExpanded = onToggleExpanded {
                Button(action: {
                    isExpanded.toggle()
                    onToggleExpanded()
                }) {
                    Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 20))
                        .frame(width: 40, height: 44)
                }
            }
        }
        .padding(EdgeInsets(top: -2, leading: 4, bottom: -2, trailing: 6))
        .border(width: isScrolled ? 1 : 0, edges: [.bottom], color: Color(UXColor.separator).opacity(0.3))
    }

    private var textView: some View {
        WrappedTextView(text: viewModel.text, viewModel: viewModel, isAutomaticLinkDetectionEnabled: isAutomaticLinkDetectionEnabled, isScrolled: $isScrolled)
    }
#else
    var body: some View {
        VStack(spacing: 0) {
#if os(macOS)
            ZStack(alignment: .bottom) {
                WrappedTextView(text: viewModel.text, viewModel: viewModel, isAutomaticLinkDetectionEnabled: isAutomaticLinkDetectionEnabled, hasVerticalScroller: hasVerticalScroller)
                errorView
            }.onAppear(perform: onAppear)
#else
            WrappedTextView(text: viewModel.text, viewModel: viewModel, isAutomaticLinkDetectionEnabled: isAutomaticLinkDetectionEnabled)
#endif
#if !os(tvOS)
            Divider()
            SearchToobar(viewModel: viewModel)
#endif
        }
    }
#endif

    private func onAppear() {
        guard viewModel.error != nil else { return }
        viewModel.onAppear()
        withAnimation {
            errorViewOpacity = 1.0
        }
    }

    @ViewBuilder
    private var errorView: some View {
        if let error = viewModel.error?.context?.debugDescription {
            HStack {
                Spacer()
                HStack {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.title)
                    Text(error).bold()
                }
                .foregroundColor(.white)
                .padding(8)
                .background(Color.red.opacity(0.8))
                .cornerRadius(12)
                .frame(maxWidth: 400)
                Spacer()
            }
            .padding(.bottom, 16)
            .onTapGesture {
                withAnimation {
                    errorViewOpacity = 0
                }
            }
            .opacity(errorViewOpacity)
        }
    }
}

extension RichTextView where ExtraMenu == EmptyView {
    init(viewModel: RichTextViewModel) {
        self.init(viewModel: viewModel, extraMenu: { EmptyView() })
    }
}

#if os(tvOS) || os(iOS)
private struct WrappedTextView: UIViewRepresentable {
    let text: NSAttributedString
    let viewModel: RichTextViewModel
    let isAutomaticLinkDetectionEnabled: Bool
    #if os(iOS)
    @Binding var isScrolled: Bool
    #endif

    final class Coordinator {
        var cancellables: [AnyCancellable] = []
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UXTextView {
        let textView = UITextView()
        configureTextView(textView)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
#if !os(tvOS)
        textView.isAutomaticLinkDetectionEnabled = isAutomaticLinkDetectionEnabled
#endif
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        textView.attributedText = text
#if os(iOS)
        textView.publisher(for: \.contentOffset, options: [.new])
            .map { $0.y >= 10 }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { isScrolled in
                withAnimation {
                    self.isScrolled = isScrolled
                }
            }
            .store(in: &context.coordinator.cancellables)
#endif
        viewModel.textView = textView
        return textView
    }

    func updateUIView(_ uiView: UXTextView, context: Context) {
        // Do nothing
    }
}
#elseif os(macOS)
private struct WrappedTextView: NSViewRepresentable {
    let text: NSAttributedString
    let viewModel: RichTextViewModel
    let isAutomaticLinkDetectionEnabled: Bool
    var hasVerticalScroller: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = hasVerticalScroller
        let textView = scrollView.documentView as! NSTextView
        configureTextView(textView)
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = NSSize(width: 10, height: 10)
        viewModel.textView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = (nsView.documentView as! NSTextView)
        textView.attributedText = text
        viewModel.textView = textView
    }
}
#endif

private func configureTextView(_ textView: UXTextView) {
    textView.isSelectable = true
#if !os(tvOS)
    textView.isEditable = false
    textView.linkTextAttributes = [
        .foregroundColor: JSONColors.valueString,
        .underlineStyle: 1
    ]
#endif
    textView.backgroundColor = .clear
}
#endif

#if os(iOS) || os(macOS)
private struct SearchToobar: View {
    @ObservedObject var viewModel: RichTextViewModel

#if os(iOS)
    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Button(action: viewModel.previousMatch) {
                    Image(systemName: "chevron.left.circle")
                        .font(.system(size: 20))
                }.disabled(viewModel.matches.isEmpty)
                Text(viewModel.matches.isEmpty ? "0 of 0" : "\(viewModel.selectedMatchIndex+1) of \(viewModel.matches.count)")
                    .font(Font.body.monospacedDigit())
                Button(action: viewModel.nextMatch) {
                    Image(systemName: "chevron.right.circle")
                        .font(.system(size: 20))
                }.disabled(viewModel.matches.isEmpty)
            }
            .fixedSize()
            Spacer()

            Button(action: viewModel.cancelSearch) {
                Text("Cancel")
            }
        }
        .padding(12)
        .border(width: 1, edges: [.top], color: Color(UXColor.separator).opacity(0.3))
        .backport.backgroundThickMaterial()
    }
#else
    var body: some View {
        HStack {
            SearchBar(title: "Search", text: $viewModel.searchTerm, onEditingChanged: { isEditing in
                if isEditing {
                    viewModel.isSearching = isEditing
                }
            }, onReturn: viewModel.nextMatch).frame(maxWidth: 240)

            Menu(content: {
                StringSearchOptionsMenu(options: $viewModel.options, isKindNeeded: false)
            }, label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .frame(width: 40, height: 44)
            })
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            HStack(spacing: 12) {
                Text(viewModel.matches.isEmpty ? "0/0" : "\(viewModel.selectedMatchIndex+1)/\(viewModel.matches.count)")
                    .font(Font.body.monospacedDigit())
                    .foregroundColor(.secondary)
                Button(action: viewModel.previousMatch) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .disabled(viewModel.matches.isEmpty)
                Button(action: viewModel.nextMatch) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .disabled(viewModel.matches.isEmpty)
            }
            .fixedSize()
        }
        .padding(6)
    }
#endif
}

final class RichTextViewModel: ObservableObject {
    @Published private(set) var selectedMatchIndex: Int = 0
    @Published private(set) var matches: [Range<String.Index>] = []
    @Published var isSearching = false
    @Published var searchTerm: String = ""
    @Published var options: StringSearchOptions = .default
    var error: NetworkLogger.DecodingError?

    let text: NSAttributedString
    private let string: String

    weak var textView: UXTextView?
    var mutableText: NSMutableAttributedString {
        textView?.textStorage ?? NSMutableAttributedString()
    }

    var isAutomaticLinkDetectionEnabled = true

    private var bag = [AnyCancellable]()

    convenience init(json: Any, error: NetworkLogger.DecodingError?) {
        let renderer = AttributedStringJSONRenderer(fontSize: FontSize.body, lineHeight: FontSize.body + 5)
        let printer = JSONPrinter(renderer: renderer)
        printer.render(json: json, error: error)
        self.init(string: renderer.make())
        self.error = error
    }

    convenience init(string: String) {
        self.init(string: RichTextViewModel.makeAttributedString(for: string))
    }

    static func makeAttributedString(for string: String) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [.font: preferredFont(), .foregroundColor: UXColor.label])
    }

    static func preferredFont() -> UXFont {
#if os(macOS)
        NSFont.preferredFont(forTextStyle: .body, options: [:])
#else
        UXFont.systemFont(ofSize: FontSize.body + 3, weight: .regular)
#endif
    }

    init(string: NSAttributedString) {
        self.text = string
        self.string = string.string

        Publishers.CombineLatest($searchTerm, $options).sink { [weak self] in
            self?.refresh(searchTerm: $0, options: $1)
        }.store(in: &bag)
    }

    func onAppear() {
        if error != nil {
            let range = NSRange(location: 0, length: text.length)
            text.enumerateAttribute(.decodingError, in: range) { _, range, _ in
                var range = range
                if range.location > 50 {
                    range.location -= 50
                }
                textView?.scrollRangeToVisible(range)
            }
        }
    }

    private func refresh(searchTerm: String, options: StringSearchOptions) {
        selectedMatchIndex = 0
        clearMatches()

        guard !searchTerm.isEmpty, searchTerm.count > 1 else {
            return
        }

        let ranges = string.ranges(of: searchTerm, options: .init(options))
        for range in ranges {
            highlight(range: range, in: mutableText)
        }
        selectedMatchIndex = 0
        matches = ranges

        didUpdateCurrentSelectedMatch()
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
            highlight(range: matches[previousMatch], in: mutableText)
        }
        highlight(range: matches[selectedMatchIndex], in: mutableText, isFocused: true)
    }

    private func clearMatches() {
        for match in matches {
            let range = NSRange(match, in: string)
            mutableText.removeAttribute(.foregroundColor, range: range)
            if let originalForegroundColor = text.attribute(.foregroundColor, at: range.lowerBound, effectiveRange: nil) {
                mutableText.addAttribute(.foregroundColor, value: originalForegroundColor, range: range)
            }
            mutableText.removeAttribute(.backgroundColor, range: range)
        }
        matches.removeAll()
    }
}

private func highlight(range: Range<String.Index>, in text: NSMutableAttributedString, isFocused: Bool = false) {
    let range = NSRange(range, in: text.string)
    text.addAttributes([
        .backgroundColor: UXColor.systemBlue.withAlphaComponent(isFocused ? 0.8 : 0.3),
        .foregroundColor: UXColor.white
    ], range: range)
}

#if DEBUG
struct RichTextView_Previews: PreviewProvider {
    static var previews: some View {
        RichTextView(viewModel: .init(json: try! JSONSerialization.jsonObject(with: MockJSON.allPossibleValues), error: nil))
            .frame(height: 600)
            .previewLayout(.sizeThatFits)
    }
}
#endif

#endif

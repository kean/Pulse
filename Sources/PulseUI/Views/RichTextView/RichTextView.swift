// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(macOS) || os(iOS)

// TODO: handle "Expand" and other custom actions using gesture recognizer and not URLs which are slow
struct RichTextView: View {
    let viewModel: RichTextViewModel

    private var isTextViewBarItemsHidden = false

    init(viewModel: RichTextViewModel) {
        self.viewModel = viewModel
    }

    func textViewBarItemsHidden(_ isHidden: Bool) -> RichTextView {
        var copy = self
        copy.isTextViewBarItemsHidden = isHidden
        return copy
    }

    var body: some View {
        if #available(iOS 15, *) {
            _RichTextView(viewModel: viewModel, isTextViewBarItemsHidden: isTextViewBarItemsHidden)
        } else {
#if os(iOS)
            LegacyRichTextView(viewModel: viewModel)
#endif
        }
    }
}

@available(iOS 15, *)
struct _RichTextView: View {
    @ObservedObject var viewModel: RichTextViewModel
    let isTextViewBarItemsHidden: Bool

    @State private var shareItems: ShareItems?
    @State private var isWebViewOpen = false
    @State private var isMenuHidden = true

#if os(iOS)
    var body: some View {
        ContentView(viewModel: viewModel)
            .searchable(text: $viewModel.searchTerm)
            .navigationBarItems(trailing: navigationBarTrailingItems)
            .sheet(item: $shareItems, content: ShareView.init)
            .sheet(isPresented: $isWebViewOpen) {
                NavigationView {
                    WebView(data: viewModel.text.string.data(using: .utf8) ?? Data(), contentType: "application/html")
                        .inlineNavigationTitle("Browser Preview")
                        .navigationBarItems(trailing: Button(action: {
                            isWebViewOpen = false
                        }) { Image(systemName: "xmark") })
                }
            }
    }

    // Has to be like this to make isSearching work
    private struct ContentView: View {
        @ObservedObject var viewModel: RichTextViewModel
        @Environment(\.isSearching) var isSearching
        @State private var isRealMenuShown = false

        var body: some View {
            WrappedTextView(viewModel: viewModel)
                .edgesIgnoringSafeArea([.bottom])
                .overlay {
                    if isSearching {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                searchControl
                                    .padding()
                            }
                        }
                    }
                }
                .onReceive(Keyboard.isHidden) { isKeyboardHidden in
                    // Show a non-interactive placeholeder during animation,
                    // then show the actual menu when navigation is setled.
                    withAnimation(nil) {
                        isRealMenuShown = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(750)) {
                        withAnimation(nil) {
                            isRealMenuShown = true
                        }
                    }
                }
        }



        private var searchControl: some View {
            HStack(alignment: .center, spacing: 24) {
                ZStack {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                        .opacity(isRealMenuShown ? 0 : 1)
                    if isRealMenuShown {
                        Menu(content: {
                            StringSearchOptionsMenu(options: $viewModel.searchOptions, isKindNeeded: false)
                        }, label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 20))
                        })
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                }
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

            }
            .padding(12)
            .background(Material.regular)
            .cornerRadius(8)
        }
    }

    @ViewBuilder
    private var navigationBarTrailingItems: some View {
        if !isTextViewBarItemsHidden {
            HStack {
                Menu(content: {
                    AttributedStringShareMenu(shareItems: $shareItems) {
                        viewModel.textStorage
                    }
                }, label: {
                    Label("Share...", systemImage: "square.and.arrow.up")
                })
                // TODO: This should be injected/added outside of the text view
                if viewModel.contentType?.isHTML ?? false {
                    Menu(content: {
                        Section {
                            if viewModel.contentType?.isHTML == true {
                                Button(action: { isWebViewOpen = true }) {
                                    Label("Open in Browser", systemImage: "safari")
                                }
                            }
                        }
                    }, label: {
                        Image(systemName: "ellipsis.circle")
                    })
                }
            }
        }
    }
#else
    var body: some View {
        VStack(spacing: 0) {
            WrappedTextView(viewModel: viewModel)
            Divider()
            LegacyRichTextViewSearchToobar(viewModel: viewModel)
        }
    }
#endif
}

#if os(tvOS) || os(iOS)
struct WrappedTextView: UIViewRepresentable {
    let viewModel: RichTextViewModel

    final class Coordinator: NSObject, UITextViewDelegate {
        var onLinkTapped: ((URL) -> Bool)?
        var cancellables: [AnyCancellable] = []

        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            if let onLinkTapped = onLinkTapped, onLinkTapped(URL) {
                return false
            }
            if let components = URLComponents(url: URL, resolvingAgainstBaseURL: false) {
                if components.scheme == "pulse",
                   components.path == "tooltip",
                   let queryItems = components.queryItems,
                   let message = queryItems.first(where: { $0.name == "message" })?.value {
                    let title = queryItems.first(where: { $0.name == "title" })?.value
                    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                    alert.addAction(.init(title: "Done", style: .cancel))
                    UIApplication.keyWindow?.rootViewController?.present(alert, animated: true)

                    return false
                }
            }
            return true
        }
    }

    func makeUIView(context: Context) -> UXTextView {
        let textView = UITextView()
        configureTextView(textView)
        textView.delegate = context.coordinator
        textView.attributedText = viewModel.text
        context.coordinator.cancellables = bind(viewModel, textView)
        viewModel.textView = textView
        return textView
    }

    func updateUIView(_ uiView: UXTextView, context: Context) {
        // Do nothing
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator()
        coordinator.onLinkTapped = viewModel.onLinkTapped
        return coordinator
    }
}
#elseif os(macOS)
private struct WrappedTextView: NSViewRepresentable {
    let viewModel: RichTextViewModel

    final class Coordinator: NSObject {
        var cancellables: [AnyCancellable] = []
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        let textView = scrollView.documentView as! NSTextView
        configureTextView(textView)
        textView.attributedText = viewModel.text
        context.coordinator.cancellables = bind(viewModel, textView)
        viewModel.textView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = (nsView.documentView as! NSTextView)
        viewModel.textView = textView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}
#endif

private func configureTextView(_ textView: UXTextView) {
    textView.isSelectable = true
    textView.isEditable = false
    textView.linkTextAttributes = [
        .underlineStyle: 1
    ]
    textView.backgroundColor = .clear

#if os(iOS)
    textView.keyboardDismissMode = .interactive
    textView.alwaysBounceVertical = true
    textView.autocorrectionType = .no
    textView.autocapitalizationType = .none
    textView.adjustsFontForContentSizeCategory = true
    textView.textContainerInset = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
#endif

#if os(macOS)
    textView.isAutomaticSpellingCorrectionEnabled = false
    textView.textContainerInset = NSSize(width: 10, height: 10)
#endif
}

private func bind(_ viewModel: RichTextViewModel, _ textView: UXTextView) -> [AnyCancellable] {
    var cancellables: [AnyCancellable] = []

    Publishers.CombineLatest(viewModel.$isLinkDetectionEnabled, ConsoleSettings.shared.$isLinkDetectionEnabled).sink {
        textView.isAutomaticLinkDetectionEnabled = $0 && $1
    }.store(in: &cancellables)

    return cancellables
}
#endif

#if DEBUG
struct RichTextView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            let json = try! JSONSerialization.jsonObject(with: MockJSON.allPossibleValues)
            let string = TextRenderer().render(json: json)
            RichTextView(viewModel: .init(string: string, contentType: "application/json"))
                .inlineNavigationTitle("Rich Text View")
        }
#if os(macOS)
            .frame(height: 600)
            .previewLayout(.sizeThatFits)
#endif
    }
}
#endif

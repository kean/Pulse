// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#warning("TODO: add other sharing options, e.g. as HTML/PDF + print")
#warning("TODO: handle clicks on decoding error on other platforms")

#if os(macOS) || os(iOS)

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
            LegacyRichTextView(viewModel: viewModel)
        }
    }
}

/// - warning: state management is broken beyond repair and needs to be
/// rewritten (using StateObject as soon as SwiftUI is updated)
@available(iOS 15, *)
struct _RichTextView: View {
    @ObservedObject var viewModel: RichTextViewModel
    let isTextViewBarItemsHidden: Bool

    @State private var shareItems: ShareItems?
    @State private var isWebViewOpen = false

#if os(iOS)
    var body: some View {
        textView
            .edgesIgnoringSafeArea([.bottom])
            .searchable(text: $viewModel.searchTerm)
            .overlay {
                if !viewModel.matches.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            matchStepperView
                                .padding()
                        }
                    }
                }
            }
            .navigationBarItems(trailing: navigationBarTrailingItems)
            .sheet(item: $shareItems, content: ShareView.init)
            .sheet(isPresented: $isWebViewOpen) {
                NavigationView {
                    WebView(data: viewModel.text.string.data(using: .utf8) ?? Data(), contentType: "application/html")
                        .navigationBarTitle("Browser Preview", displayMode: .inline)
                        .navigationBarItems(trailing: Button(action: {
                            isWebViewOpen = false
                        }) { Image(systemName: "xmark") })
                }
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
                    Label("Share As", systemImage: "square.and.arrow.up")
                })
                Menu(content: {
                    Section {
                        if viewModel.contentType?.isHTML == true {
                            Button(action: { isWebViewOpen = true }) {
                                Label("Open in Browser", systemImage: "safari")
                            }
                        }
                    }
                    Section {
                        StringSearchOptionsMenu(options: $viewModel.searchOptions, isKindNeeded: false)
                    }
                }, label: {
                    Image(systemName: "ellipsis.circle")
                })
            }
        }
    }

    private var matchStepperView: some View {
        HStack(spacing: 16) {
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

    private var textView: some View {
        WrappedTextView(viewModel: viewModel)
    }
#else
    var body: some View {
        VStack(spacing: 0) {
            WrappedTextView(viewModel: viewModel)
                .onAppear(perform: onAppear)
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

#warning("TODO: this should not be needed")
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

    viewModel.$isLinkDetectionEnabled.sink {
        textView.isAutomaticLinkDetectionEnabled = $0
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
#if os(iOS)
                .navigationBarTitle("RichTextView", displayMode: .inline)
#endif
        }
#if os(macOS)
            .frame(height: 600)
            .previewLayout(.sizeThatFits)
#endif
    }
}
#endif

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS) || os(iOS)

import SwiftUI
import CoreData
import Pulse
import Combine

struct RichTextView: View {
    @ObservedObject var viewModel: RichTextViewModel
    var isTextViewBarItemsHidden = false

    @State private var shareItems: ShareItems?
    @State private var isWebViewOpen = false

    @Environment(\.textViewSearchContext) private var searchContext

    func textViewBarItemsHidden(_ isHidden: Bool) -> RichTextView {
        var copy = self
        copy.isTextViewBarItemsHidden = isHidden
        return copy
    }

#if os(iOS)
    var body: some View {
        contents
            .onAppear { viewModel.prepare(searchContext) }
            .navigationBarItems(trailing: navigationBarTrailingItems)
            .sheet(item: $shareItems, content: ShareView.init)
            .sheet(isPresented: $isWebViewOpen) {
                NavigationView {
                    WebView(data: viewModel.textStorage.string.data(using: .utf8) ?? Data(), contentType: "application/html")
                        .inlineNavigationTitle("Browser Preview")
                        .navigationBarItems(trailing: Button(action: {
                            isWebViewOpen = false
                        }) { Image(systemName: "xmark") })
                }
            }
    }

    @ViewBuilder
    private var contents: some View {
        if #available(iOS 15, *) {
            ContentView(viewModel: viewModel)
                .searchable(text: $viewModel.searchTerm)
                .disableAutocorrection(true)
        } else {
            WrappedTextView(viewModel: viewModel)
                .edgesIgnoringSafeArea(.bottom)
        }
    }

    @available(iOS 15, *)
    private struct ContentView: View {
        @ObservedObject var viewModel: RichTextViewModel
        @Environment(\.isSearching) private var isSearching

        var body: some View {
            WrappedTextView(viewModel: viewModel)
                .edgesIgnoringSafeArea([.bottom])
                .overlay {
                    if isSearching || !viewModel.matches.isEmpty {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                RichTextViewSearchToobar(viewModel: viewModel)
                                    .padding()
                            }
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var navigationBarTrailingItems: some View {
        if !isTextViewBarItemsHidden {
            Menu(content: {
                AttributedStringShareMenu(shareItems: $shareItems) {
                    viewModel.textStorage
                }
            }, label: {
                Image(systemName: "square.and.arrow.up")
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
#else
    var body: some View {
        VStack(spacing: 0) {
            WrappedTextView(viewModel: viewModel)
                .id(ObjectIdentifier(viewModel))
            if !viewModel.isToolbarHidden {
                RichTextViewSearchToobar(viewModel: viewModel)
            }
        }
        .onAppear { viewModel.prepare(searchContext) }
    }
#endif
}

#if DEBUG
struct RichTextView_Previews: PreviewProvider {
    static var previews: some View {
        let textView = RichTextView(viewModel: makePreviewViewModel())
#if os(macOS)
        textView
            .background(Color(.textBackgroundColor))
            .frame(height: 600)
            .previewLayout(.sizeThatFits)
#else
        NavigationView {
            textView
                .inlineNavigationTitle("Rich Text View")
        }
        #endif
    }
}

private func makePreviewViewModel() -> RichTextViewModel {
    let json = try! JSONSerialization.jsonObject(with: MockJSON.allPossibleValues)
    let string = TextRenderer().render(json: json)

    let viewModel = RichTextViewModel(string: string, contentType: "application/json")
    viewModel.isLineNumberRulerEnabled = true
    viewModel.isFilterEnabled = true

    return viewModel
}
#endif

private struct TextViewSearchContextKey: EnvironmentKey {
    static var defaultValue: RichTextViewModel.SearchContext?
}

extension EnvironmentValues {
    var textViewSearchContext: RichTextViewModel.SearchContext? {
        get { self[TextViewSearchContextKey.self] }
        set { self[TextViewSearchContextKey.self] = newValue }
    }
}

#endif

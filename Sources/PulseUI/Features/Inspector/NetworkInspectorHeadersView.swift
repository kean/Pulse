// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

// MARK: - View
struct NetworkInspectorHeadersView: View {
    @ObservedObject var viewModel: NetworkInspectorHeaderViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                KeyValueSectionView(viewModel: viewModel.requestHeadersOriginal)
                KeyValueSectionView(viewModel: viewModel.requestHeadersCurrent)
                if let responseHeaders = viewModel.responseHeaders {
                    KeyValueSectionView(viewModel: responseHeaders)
                }
                Spacer()
            }.padding()
        }.background(links)
    }

    private var links: some View {
        InvisibleNavigationLinks {
            NavigationLink.programmatic(isActive: $viewModel.isRequestOriginalRawActive, destination:  { NetworkHeadersDetailsView(viewModel: viewModel.requestHeadersOriginal) })
            NavigationLink.programmatic(isActive: $viewModel.isRequestCurrentRawActive, destination:  { NetworkHeadersDetailsView(viewModel: viewModel.requestHeadersCurrent) })
            
            if let responseHeaders = viewModel.responseHeaders {
                NavigationLink.programmatic(isActive: $viewModel.isResponseRawActive, destination:  { NetworkHeadersDetailsView(viewModel: responseHeaders) })
            }
        }
    }
}

struct NetworkHeadersDetailsView: View {
    let viewModel: KeyValueSectionViewModel
    @State private var isShowingShareSheet = false

    #if os(iOS)
    var body: some View {
        contents
            .navigationBarTitle(viewModel.title)
            .navigationBarItems(trailing: ShareButton {
                isShowingShareSheet = true
            })
            .sheet(isPresented: $isShowingShareSheet) {
                ShareView(activityItems: [text])
            }
    }
    #else
    var body: some View {
        contents
    }
    #endif

    @ViewBuilder
    private var contents: some View {
        if viewModel.items.isEmpty {
            PlaceholderView(imageName: "folder", title: "Empty")
        } else {
            #if os(watchOS) || os(tvOS)
            RichTextView(viewModel: .init(string: text.string))
            #else
            RichTextView(viewModel: {
                let viewModel = RichTextViewModel(string: text)
                viewModel.isAutomaticLinkDetectionEnabled = false
                return viewModel
            }())
            #endif
        }
    }

    private var text: NSAttributedString {
        let output = NSMutableAttributedString()
        for item in viewModel.items {
            output.append(item.0, [.font: UXFont.monospacedSystemFont(ofSize: FontSize.body, weight: .bold)])
            output.append(": \(item.1 ?? "–")\n", [.font: UXFont.monospacedSystemFont(ofSize: FontSize.body, weight: .regular)])
        }
#if os(iOS) || os(macOS)
        output.addAttributes([.foregroundColor: UXColor.label])
#endif
        return output
    }
}

// MARK: - ViewModel

final class NetworkInspectorHeaderViewModel: ObservableObject {
    private let details: DecodedNetworkRequestDetailsEntity

    init(details: DecodedNetworkRequestDetailsEntity) {
        self.details = details
    }

    @Published var isRequestOriginalRawActive = false
    @Published var isRequestCurrentRawActive = false
    @Published var isResponseRawActive = false

    var requestHeadersOriginal: KeyValueSectionViewModel {
        let items = (details.originalRequest?.headers ?? [:]).sorted(by: { $0.key < $1.key })
        return KeyValueSectionViewModel(
            title: "Request Headers (Original)",
            color: .blue,
            action: ActionViewModel(
                action: { [unowned self] in isRequestOriginalRawActive = true },
                title: "View Raw"
            ),
            items: items
        )
    }

    var requestHeadersCurrent: KeyValueSectionViewModel {
        let items = (details.currentRequest?.headers ?? [:]).sorted(by: { $0.key < $1.key })
        return KeyValueSectionViewModel(
            title: "Request Headers (Current)",
            color: .blue,
            action: ActionViewModel(
                action: { [unowned self] in isRequestCurrentRawActive = true },
                title: "View Raw"
            ),
            items: items
        )
    }

    var responseHeaders: KeyValueSectionViewModel? {
        guard let headers = details.response?.headers else {
            return nil
        }
        return KeyValueSectionViewModel(
            title: "Response Headers",
            color: .indigo,
            action: ActionViewModel(
                action: { [unowned self] in isResponseRawActive = true },
                title: "View Raw"
            ),
            items: headers.sorted(by: { $0.key < $1.key })
        )
    }
}

// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

// MARK: - View
@available(iOS 13.0, tvOS 14.0, watchOS 6.0, *)
struct NetworkInspectorHeadersView: View {
    @ObservedObject var viewModel: NetworkInspectorHeaderViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                KeyValueSectionView(viewModel: viewModel.requestHeaders)
                KeyValueSectionView(viewModel: viewModel.responseHeaders)
                Spacer()
            }.padding()

            NavigationLink(destination: NetworkHeadersDetailsView(viewModel: viewModel.requestHeaders), isActive: $viewModel.isRequestRawActive) {
                Text("")
            }.hidden()

            NavigationLink(destination: NetworkHeadersDetailsView(viewModel: viewModel.responseHeaders), isActive: $viewModel.isResponseRawActive) {
                Text("")
            }.hidden()
        }
    }
}

@available(iOS 13.0, tvOS 14.0, watchOS 6.0, *)
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
            RichTextView(viewModel: .init(string: text), isAutomaticLinkDetectionEnabled: false)
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

@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
final class NetworkInspectorHeaderViewModel: ObservableObject {
    let summary: NetworkLoggerSummary

    init(summary: NetworkLoggerSummary) {
        self.summary = summary
    }

    @Published var isRequestRawActive = false
    @Published var isResponseRawActive = false

    var requestHeaders: KeyValueSectionViewModel {
        let items = (summary.request?.headers ?? [:]).sorted(by: { $0.key < $1.key })
        return KeyValueSectionViewModel(
            title: "Request Headers",
            color: .blue,
            action: ActionViewModel(
                action: { [unowned self] in isRequestRawActive = true },
                title: "View Raw"
            ),
            items: items
        )
    }

    var responseHeaders: KeyValueSectionViewModel {
        let items = (summary.response?.headers ?? [:]).sorted(by: { $0.key < $1.key })
        return KeyValueSectionViewModel(
            title: "Response Headers",
            color: .indigo,
            action: ActionViewModel(
                action: { [unowned self] in isResponseRawActive = true },
                title: "View Raw"
            ),
            items: items
        )
    }
}

// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

// MARK: - View
@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
struct NetworkInspectorHeadersView: View {
    @ObservedObject var model: NetworkInspectorHeaderViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                KeyValueSectionView(model: model.requestHeaders)
                if let additional = model.httpAdditionalHeaders {
                    KeyValueSectionView(model: additional)
                }
                KeyValueSectionView(model: model.responseHeaders)
                Spacer()
            }.padding()

            NavigationLink(destination: NetworkHeadersDetailsView(model: model.requestHeaders), isActive: $model.isRequestRawActive) {
                Text("")
            }.hidden()
            
            if let additional = model.httpAdditionalHeaders {
                NavigationLink(destination: NetworkHeadersDetailsView(model: additional), isActive: $model.isRequestAdditionalHeadersRawActive) {
                    Text("")
                }.hidden()
            }

            NavigationLink(destination: NetworkHeadersDetailsView(model: model.responseHeaders), isActive: $model.isResponseRawActive) {
                Text("")
            }.hidden()
        }
    }
}

@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
struct NetworkHeadersDetailsView: View {
    let model: KeyValueSectionViewModel
    @State private var isShowingShareSheet = false

    #if os(iOS)
    var body: some View {
        contents
            .navigationBarTitle(model.title)
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
        if model.items.isEmpty {
            PlaceholderView(imageName: "folder", title: "Empty")
        } else {
            #if os(watchOS) || os(tvOS)
            DopeTextView(model: .init(string: text.string))
            #else
            DopeTextView(model: .init(string: text), isAutomaticLinkDetectionEnabled: false)
            #endif
        }
    }

    private var text: NSAttributedString {
        let output = NSMutableAttributedString()
        for item in model.items {
            output.append(item.0, [.font: UXFont.monospacedSystemFont(ofSize: FontSize.body, weight: .bold)])
            output.append(": \(item.1 ?? "–")\n", [.font: UXFont.monospacedSystemFont(ofSize: FontSize.body, weight: .regular)])
        }
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
    @Published var isRequestAdditionalHeadersRawActive = false
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
    
    var httpAdditionalHeaders: KeyValueSectionViewModel? {
        guard let headers = summary.session?.httpAdditionalHeaders else {
            return nil
        }
        let items = headers.sorted(by: { $0.key < $1.key })
        return KeyValueSectionViewModel(
            title: "Request Headers (Additional)",
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

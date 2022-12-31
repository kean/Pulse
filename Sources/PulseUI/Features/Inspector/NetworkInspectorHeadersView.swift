// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct NetworkInspectorHeadersView: View {
    @ObservedObject var viewModel: NetworkInspectorHeaderViewModel

    var body: some View {
        VStack(spacing: 16) {
            KeyValueSectionView(viewModel: viewModel.requestHeadersOriginal)
            KeyValueSectionView(viewModel: viewModel.requestHeadersCurrent)
            if let responseHeaders = viewModel.responseHeaders {
                KeyValueSectionView(viewModel: responseHeaders)
            }
        }
        .padding()
        .background(links)
    }

    private var links: some View {
        InvisibleNavigationLinks {
            NavigationLink.programmatic(isActive: $viewModel.isRequestOriginalRawActive, destination:  { NetworkDetailsView(viewModel: viewModel.requestHeadersOriginal) })
            NavigationLink.programmatic(isActive: $viewModel.isRequestCurrentRawActive, destination:  { NetworkDetailsView(viewModel: viewModel.requestHeadersCurrent) })
            
            if let responseHeaders = viewModel.responseHeaders {
                NavigationLink.programmatic(isActive: $viewModel.isResponseRawActive, destination:  { NetworkDetailsView(viewModel: responseHeaders) })
            }
        }
    }
}

struct NetworkDetailsView: View {
    private var title: String
    private let text: NSAttributedString
    @State private var isShowingShareSheet = false

    init(viewModel: KeyValueSectionViewModel) {
        self.title = viewModel.title
        self.text = viewModel.asAttributedString()
    }

    init(title: String, text: NSAttributedString) {
        self.title = title
        self.text = text
    }

    func title(_ title: String) -> NetworkDetailsView {
        var copy = self
        copy.title = title
        return copy
    }

    #if os(iOS)
    var body: some View {
        contents
            .navigationBarTitle(title)
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
        if text.string.isEmpty {
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
}

// MARK: - ViewModel

final class NetworkInspectorHeaderViewModel: ObservableObject {
    private let task: NetworkTaskEntity

    init(task: NetworkTaskEntity) {
        self.task = task
    }

    @Published var isRequestOriginalRawActive = false
    @Published var isRequestCurrentRawActive = false
    @Published var isResponseRawActive = false

    var requestHeadersOriginal: KeyValueSectionViewModel {
        let items = (task.originalRequest?.headers ?? [:]).sorted(by: { $0.key < $1.key })
        return KeyValueSectionViewModel(
            title: "Request Headers (Original)",
            color: .blue,
            action: ActionViewModel(title: "View Raw") { [unowned self] in
                isRequestOriginalRawActive = true
            },
            items: items
        )
    }

    var requestHeadersCurrent: KeyValueSectionViewModel {
        let items = (task.currentRequest?.headers ?? [:]).sorted(by: { $0.key < $1.key })
        return KeyValueSectionViewModel(
            title: "Request Headers (Current)",
            color: .blue,
            action: ActionViewModel(title: "View Raw") { [unowned self] in
                isRequestCurrentRawActive = true
            },
            items: items
        )
    }

    var responseHeaders: KeyValueSectionViewModel? {
        guard let headers = task.response?.headers else {
            return nil
        }
        return KeyValueSectionViewModel(
            title: "Response Headers",
            color: .indigo,
            action: ActionViewModel(title: "View Raw") { [unowned self] in
                isResponseRawActive = true
            },
            items: headers.sorted(by: { $0.key < $1.key })
        )
    }
}

#if DEBUG
struct NetworkInspectorHeadersView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NetworkInspectorHeadersView(viewModel: .init(task: LoggerStore.preview.entity(for: .login)))
        }
    }
}
#endif

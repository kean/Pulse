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
                ShareView(activityItems: [viewModel.asAttributedString()])
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
            RichTextView(viewModel: .init(string: viewModel.asAttributedString().string))
            #else
            RichTextView(viewModel: {
                let viewModel = RichTextViewModel(string: viewModel.asAttributedString())
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
            action: ActionViewModel(
                action: { [unowned self] in isRequestOriginalRawActive = true },
                title: "View Raw"
            ),
            items: items
        )
    }

    var requestHeadersCurrent: KeyValueSectionViewModel {
        let items = (task.currentRequest?.headers ?? [:]).sorted(by: { $0.key < $1.key })
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
        guard let headers = task.response?.headers else {
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

#if DEBUG
struct NetworkInspectorHeadersView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NetworkInspectorHeadersView(viewModel: .init(task: LoggerStore.preview.entity(for: .login)))
        }
    }
}
#endif

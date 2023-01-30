// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(macOS)

struct NetworkInspectorView: View {
    @ObservedObject var task: NetworkTaskEntity
    @AppStorage("networkInspectorSelectedTab") private var selectedTab: NetworkInspectorTab = .response
    @Environment(\.colorScheme) private var colorScheme
    var onClose: () -> Void

    private var viewModel: NetworkInspectorViewModel { .init(task: task) }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            selectedTabView
        }
        .toolbar {
            if #available(macOS 13, *), let url = viewModel.shareTaskAsHTML() {
                ShareLink(item: url)
            }
        }
    }

    @ViewBuilder
    private var toolbar: some View {
        HStack {
            InlineTabBar(items: NetworkInspectorTab.allCases, selection: $selectedTab)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
            }.buttonStyle(.plain)
        }.padding(EdgeInsets(top: 7, leading: 10, bottom: 6, trailing: 8))
    }

    @ViewBuilder
    private var selectedTabView: some View {
        switch selectedTab {
        case .summary:
            RichTextView(viewModel: .init(string: TextRenderer(options: .sharing).make { $0.render(task, content: .sharing) }))
        case .headers:
            RichTextView(viewModel: .init(string: renderHeaders()))
        case .request:
            NetworkInspectorRequestBodyView(viewModel: .init(task: task))
        case .response:
            NetworkInspectorResponseBodyView(viewModel: .init(task: task))
        case .metrics:
            if let viewModel = NetworkInspectorMetricsViewModel(task: task) {
                NetworkInspectorMetricsView(viewModel: viewModel)
            } else {
                placeholder
            }
        case .curl:
            RichTextView(viewModel: .init(string: TextRenderer().preformatted(task.cURLDescription())))
        }
    }

    private func renderHeaders() -> NSAttributedString {
        TextRenderer().make {
            $0.render([
                KeyValueSectionViewModel.makeHeaders(title: "Original Request Headers", headers: task.originalRequest?.headers),
                KeyValueSectionViewModel.makeHeaders(title: "Current Request Headers", headers: task.currentRequest?.headers),
                KeyValueSectionViewModel.makeHeaders(title: "Response Headers", headers: task.response?.headers)
            ])
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        PlaceholderView(imageName: "exclamationmark.circle", title: "Not Available")
    }
}

private enum NetworkInspectorTab: String, Identifiable, CaseIterable, CustomStringConvertible {
    case summary = "Summary"
    case headers = "Headers"
    case request = "Request"
    case response = "Response"
    case metrics = "Metrics"
    case curl = "cURL"

    var id: NetworkInspectorTab { self }
    var description: String { self.rawValue }
}

#if DEBUG
struct NetworkInspectorView_Previews: PreviewProvider {
    static var previews: some View {
            if #available(macOS 13.0, *) {
                NavigationStack {
                    NetworkInspectorView(task: LoggerStore.preview.entity(for: .login), onClose: {})
                }.previewLayout(.fixed(width: 280, height: 800))
            }
        }
}
#endif

#endif

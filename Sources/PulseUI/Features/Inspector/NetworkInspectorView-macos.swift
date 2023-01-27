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
            NetworkTabView(selectedTab: $selectedTab)
            Spacer()
        }.padding(EdgeInsets(top: 7, leading: 10, bottom: 6, trailing: 10))
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

private struct NetworkTabView: View {
    @Binding var selectedTab: NetworkInspectorTab

    var body: some View {
        HStack(spacing: 0) {
            HStack {
                makeItem("Response", tab: .response)
                Divider()
                makeItem("Request", tab: .request)
                Divider()
                makeItem("Headers", tab: .headers)
                Divider()
            }
            HStack {
                Spacer().frame(width: 8)
                makeItem("Summary", tab: .summary)
                Divider()
                makeItem("Metrics", tab: .metrics)
                Divider()
                makeItem("cURL", tab: .curl)
            }
        }.fixedSize()
    }

    private func makeItem(_ title: String, tab: NetworkInspectorTab) -> some View {
        Button(action: {
            selectedTab = tab
        }) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .default))
                .foregroundColor(tab == selectedTab ? .accentColor : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private enum NetworkInspectorTab: String, Identifiable {
    case summary
    case headers
    case request
    case response
    case metrics
    case curl

    var id: NetworkInspectorTab { self }

    var text: String {
        switch self {
        case .summary: return "Summary"
        case .headers: return "Headers"
        case .request: return "Request"
        case .response: return "Response"
        case .metrics: return "Metrics"
        case .curl: return "cURL"
        }
    }
}

#if DEBUG
struct NetworkInspectorView_Previews: PreviewProvider {
    static var previews: some View {
            if #available(macOS 13.0, *) {
                NavigationStack {
                    NetworkInspectorView(task: LoggerStore.preview.entity(for: .login))
                }.previewLayout(.fixed(width: ConsoleView.contentColumnWidth, height: 800))
            }
        }
}
#endif

#endif

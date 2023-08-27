// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS) && !PULSE_STANDALONE_APP

import SwiftUI
import CoreData
import Pulse
import Combine

struct NetworkInspectorView: View {
    @ObservedObject var task: NetworkTaskEntity
    @State var selectedTab: NetworkInspectorTab
    @Environment(\.store) private var store

    init(task: NetworkTaskEntity,
         tab: NetworkInspectorTab = NetworkInspectorPreferences().selectedTab) {
        self.task = task
        self._selectedTab = State(initialValue: tab)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            selectedTabView
        }
        .onChange(of: selectedTab) {
            NetworkInspectorPreferences().selectedTab = $0
        }
    }

    @ViewBuilder
    private var toolbar: some View {
        HStack {
            InlineTabBar(items: NetworkInspectorTab.allCases, selection: $selectedTab)
            Spacer()

            ButtonCloseDetailsView()
        }
        .padding(.horizontal, 10)
        .offset(y: -2)
        .frame(height: 27, alignment: .center)
    }

    @ViewBuilder
    private var selectedTabView: some View {
        switch selectedTab {
        case .summary:
            RichTextView(viewModel: .init(string: TextRenderer(options: .sharing).make { $0.render(task, content: .summary, store: store) }))
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
        TextRenderer(options: .init(color: .monochrome)).make {
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

private struct NetworkInspectorPreferences {
    // We want to save the latest preferences, but not update all open windows
    // on the change in selection.
    @AppStorage("network-inspector-selected-tab")
    var selectedTab: NetworkInspectorTab = .summary
}

enum NetworkInspectorTab: String, Identifiable, CaseIterable, CustomStringConvertible {
    case summary = "Summary"
    case request = "Request"
    case response = "Response"
    case headers = "Headers"
    case metrics = "Metrics"
    case curl = "cURL"

    var id: NetworkInspectorTab { self }
    var description: String { self.rawValue }
}

#if DEBUG
@available(macOS 13, *)
struct Previews_NetworkInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            NetworkInspectorView(task: LoggerStore.preview.entity(for: .login))
        }.previewLayout(.fixed(width: 500, height: 800))
    }
}
#endif

#endif

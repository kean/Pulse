// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#warning("TODO: remove this")

#if os(no)

#warning("TODO: remove onClose")

struct NetworkInspectorView: View {
    @ObservedObject var viewModel: NetworkInspectorViewModel

    var onClose: (() -> Void)?

    @State private var selectedTab: NetworkInspectorTab = .response
    @State private var shareItems: ShareItems?

    var body: some View {
        VStack {
            toolbar
            selectedTabView
        }
    }

    private var toolbar: some View {
        VStack(spacing: 0) {
            HStack {
                NetworkTabPickerView(selectedTab: $selectedTab)
                Spacer()
                if let onClose = onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark").foregroundColor(.secondary)
                    }.buttonStyle(PlainButtonStyle())
                }
            }
            .padding(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 10))
            Divider()
        }
    }

    @ViewBuilder
    private var selectedTabView: some View {
        switch selectedTab {
        case .response:
            NetworkInspectorResponseView(viewModel: viewModel.responseViewModel)
        case .request:
            NetworkInspectorRequestView(viewModel: viewModel.requestViewModel)
        case .summary:
            NetworkInspectorSummaryView(viewModel: viewModel.summaryViewModel)
        case .headers:
            NetworkInspectorHeadersTabView(viewModel: viewModel.headersViewModel)
        case .metrics:
            NetworkInspectorMetricsTabView(viewModel: viewModel.metricsViewModel)
        }
    }
}

private enum NetworkInspectorTab: Identifiable {
    case summary
    case headers
    case request
    case response
    case metrics

    var id: NetworkInspectorTab { self }

    var text: String {
        switch self {
        case .summary: return "Summary"
        case .headers: return "Headers"
        case .request: return "Request"
        case .response: return "Response"
        case .metrics: return "Metrics"
        }
    }
}

private struct NetworkTabPickerView: View {
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
            }
        }.fixedSize()
    }

    private func makeItem(_ title: String, tab: NetworkInspectorTab) -> some View {
        Button(action: { selectedTab = tab }) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .default))
                .foregroundColor(tab == selectedTab ? .accentColor : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#if DEBUG
struct NetworkInspectorViewMacOS_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                NetworkInspectorView(viewModel: .init(task: LoggerStore.preview.entity(for: .login)))
            }.previewDisplayName("Success")
            NavigationView {
                NetworkInspectorView(viewModel: .init(task: LoggerStore.preview.entity(for: .patchRepo)))
            }.previewDisplayName("Failure")
        }
    }
}
#endif

#endif

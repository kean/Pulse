// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

struct NetworkInspectorView: View {
    // Make sure all tabs are updated live
    @ObservedObject var viewModel: NetworkInspectorViewModel
    var onClose: (() -> Void)?

    @State private var selectedTab: NetworkInspectorTab = .response
    @State private var isShowingShareSheet = false
    @State private var shareItems: ShareItems?
    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme

#if os(iOS)
    @State private var viewController: UIViewController?

    var body: some View {
        VStack(spacing: 0) {
            if !isExpanded {
                toolbar
            }
            selectedTabView
        }
        .navigationBarItems(trailing: trailingNavigationBarItems)
        .navigationBarHidden(isExpanded)
        .navigationBarTitle(Text(viewModel.title), displayMode: .inline)
        .statusBar(hidden: UIDevice.current.userInterfaceIdiom == .phone && isExpanded)
        .sheet(isPresented: $isShowingShareSheet) {
            ShareView(activityItems: [viewModel.prepareForSharing()])
        }
        .sheet(item: $shareItems, content: ShareView.init)
        .background(ViewControllerAccessor(viewController: $viewController))
    }

    private var toolbar: some View {
        Picker("", selection: $selectedTab) {
            Text("Response").tag(NetworkInspectorTab.response)
            Text("Request").tag(NetworkInspectorTab.request)
            Text("Summary").tag(NetworkInspectorTab.summary)
            Text("Metrics").tag(NetworkInspectorTab.metrics)
        }
        .pickerStyle(.segmented)
        .padding(EdgeInsets(top: 4, leading: 13, bottom: 11, trailing: 13))
        .border(width: 1, edges: [.bottom], color: Color(UXColor.separator).opacity(0.3))
    }

    @ViewBuilder
    private var trailingNavigationBarItems: some View {
        HStack {
            if let pin = viewModel.pin {
                PinButton(viewModel: pin, isTextNeeded: false)
            }
            if #available(iOS 14.0, *) {
                Menu(content: {
                    NetworkMessageContextMenu(request: viewModel.request, store: viewModel.store, sharedItems: $shareItems)
                }, label: {
                    Image(systemName: "ellipsis.circle")
                })
            } else {
                ShareButton {
                    isShowingShareSheet = true
                }
            }
        }
    }
#elseif os(macOS)
    var body: some View {
        VStack {
            toolbar
            selectedTabView
        }
        .background(colorScheme == .light ? Color(UXColor.controlBackgroundColor) : Color.clear)
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
#elseif os(watchOS)
    var body: some View {
        NetworkInspectorSummaryView(viewModel: viewModel.summaryViewModel)
            .navigationBarTitle(Text(viewModel.title))
            .toolbar {
                if let viewModel = viewModel.pin {
                    PinButton(viewModel: viewModel, isTextNeeded: false)
                }
            }
    }
#elseif os(tvOS)
    var body: some View {
        NetworkInspectorSummaryView(viewModel: viewModel.summaryViewModel)
    }
#endif

#if os(iOS) || os(macOS)
    @ViewBuilder
    private var selectedTabView: some View {
        switch selectedTab {
        case .response:
            NetworkInspectorResponseView(viewModel: viewModel.responseViewModel, onToggleExpanded: onToggleExpanded)
        case .request:
            NetworkInspectorRequestView(viewModel: viewModel.requestViewModel, onToggleExpanded: onToggleExpanded)
        case .summary:
            NetworkInspectorSummaryView(viewModel: viewModel.summaryViewModel)
        case .headers:
            NetworkInspectorHeadersTabView(viewModel: viewModel.headersViewModel)
        case .metrics:
            NetworkInspectorMetricsTabView(viewModel: viewModel.metricsViewModel)
        }
    }

    func onToggleExpanded() {
#if os(iOS)
        isExpanded.toggle()
        viewController?.navigationController?.setNavigationBarHidden(isExpanded, animated: false)
        viewController?.tabBarController?.setTabBarHidden(isExpanded, animated: false)
#endif
    }
#endif
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

#if os(macOS)
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
#endif

// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

struct NetworkInspectorSummaryView: View {
    @ObservedObject var viewModel: NetworkInspectorSummaryViewModel
    @State var isShowingCurrentRequest = false

    var body: some View {
#if os(iOS) || os(macOS)
        ScrollView {
            VStack {
                contents
            }.padding()
        }.background(links)
#elseif os(watchOS)
        ScrollView {
            Spacer().frame(height: 24)
            VStack(spacing: 24) {
                contents
            }
        }.background(links)
#elseif os(tvOS)
        List {
            contents
        }
#endif
    }

#if os(iOS) || os(macOS)
    @ViewBuilder
    private var contents: some View {
        headerView

        summaryView
        viewModel.errorModel.map(KeyValueSectionView.init)

        if viewModel.originalRequestSummary != nil {
            if isShowingCurrentRequest {
                currentRequestSection
            } else {
                originalRequestSection
            }
        }

        if viewModel.responseSummary != nil {
            responseSection
        }
    }

    @ViewBuilder
    private var requestHeaderView: some View {
        HStack {
            LargeSectionHeader(title: "Request", accessory: {
                Picker("Request Type", selection: $isShowingCurrentRequest) {
                    Text("Original").tag(false)
                    Text("Current").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            })
        }
    }

    @ViewBuilder
    private var originalRequestSection: some View {
        Section(header: requestHeaderView) {
            viewModel.originalRequestSummary.map(KeyValueSectionView.init)
            viewModel.originalRequestQueryItems.map { KeyValueSectionView(viewModel: $0, limit: 10) }
            KeyValueSectionView(viewModel: viewModel.originalRequestHeaders, limit: 10)
            KeyValueSectionView(viewModel: viewModel.requestBodySection)
            viewModel.originalRequestParameters.map(KeyValueSectionView.init)
        }
    }

    @ViewBuilder
    private var currentRequestSection: some View {
        Section(header: requestHeaderView) {
            viewModel.currentRequestSummary.map(KeyValueSectionView.init)
            viewModel.currentRequestQueryItems.map { KeyValueSectionView(viewModel: $0, limit: 10) }
            KeyValueSectionView(viewModel: viewModel.currentRequestHeaders, limit: 10)
            KeyValueSectionView(viewModel: viewModel.requestBodySection)
            viewModel.currentRequestParameters.map(KeyValueSectionView.init)
        }
    }

    @ViewBuilder
    private var responseSection: some View {
        Section(header: LargeSectionHeader(title: "Response")) {
            viewModel.responseSummary.map(KeyValueSectionView.init)
            KeyValueSectionView(viewModel: viewModel.responseHeaders, limit: 10)
            KeyValueSectionView(viewModel: viewModel.responseBodySection)
        }
    }
#elseif os(watchOS)
    @ViewBuilder
    private var contents: some View {
        headerView

        // Summary
        summaryView
        viewModel.errorModel.map(KeyValueSectionView.init)
        // HTTP Body
        KeyValueSectionView(viewModel: viewModel.requestBodySection)
        KeyValueSectionView(viewModel: viewModel.responseBodySection)
        // HTTTP Headers
        KeyValueSectionView(viewModel: viewModel.originalRequestHeaders, limit: 10)
        KeyValueSectionView(viewModel: viewModel.responseHeaders, limit: 10)
        // Timing
        viewModel.timingDetailsModel.map(KeyValueSectionView.init)
    }
#elseif os(tvOS)
    var metrics: NetworkInspectorMetricsViewModel?

    @ViewBuilder
    private var contents: some View {
        headerView

        NavigationLink(destination: KeyValueSectionView(viewModel: viewModel.summaryModel).focusable(true)) {
            summaryView
        }

        if let error = viewModel.errorModel {
            makeKeyValueSection(viewModel: error)
        }
        NavigationLink(destination: NetworkInspectorResponseView(viewModel: viewModel.requestBodyViewModel).focusable(true)) {
            KeyValueSectionView(viewModel: viewModel.requestBodySection)
        }
        if viewModel.responseSummary != nil {
            NavigationLink(destination: NetworkInspectorResponseView(viewModel: viewModel.responseBodyViewModel).focusable(true)) {
                KeyValueSectionView(viewModel: viewModel.responseBodySection)
            }
        }
        makeKeyValueSection(viewModel: viewModel.originalRequestHeaders)
        if viewModel.responseSummary != nil {
            makeKeyValueSection(viewModel: viewModel.responseHeaders)
        }
        if let timing = viewModel.timingDetailsModel, let metrics = metrics {
            NavigationLink(destination: NetworkInspectorMetricsView(viewModel: metrics).focusable(true)) {
                KeyValueSectionView(viewModel: timing)
            }
        }
    }

    func makeKeyValueSection(viewModel: KeyValueSectionViewModel) -> some View {
        NavigationLink(destination: KeyValueSectionView(viewModel: viewModel).focusable(true)) {
            KeyValueSectionView(viewModel: viewModel, limit: 5)
        }
    }
#endif
    @ViewBuilder
    private var headerView: some View {
        if let transfer = viewModel.transferModel {
            NetworkInspectorTransferInfoView(viewModel: transfer)
        } else if viewModel.state == .pending {
            ZStack {
                NetworkInspectorTransferInfoView(viewModel: .init(empty: true))
                    .hidden()
                    .backport.hideAccessibility()
                SpinnerView(viewModel: viewModel.progress)
            }
        }
    }

    private var summaryView: some View {
        VStack {
            HStack(spacing: spacing) {
                Text(viewModel.summaryModel.title)
                statusView
                Spacer()
            }.font(.headline)

            KeyValueSectionView(viewModel: viewModel.summaryModel)
                .hiddenTitle()
        }
    }

    private var statusView: some View {
        let imageName: String
        switch viewModel.state {
        case .pending: imageName = "clock.fill"
        case .success: imageName = "checkmark.circle.fill"
        case .failure: imageName = "exclamationmark.octagon.fill"
        }
        return Image(systemName: imageName)
            .foregroundColor(viewModel.tintColor)
    }

    private var links: some View {
        VStack {
            if let errorModel = viewModel.errorModel {
                NavigationLink.programmatic(isActive: $viewModel.isErrorRawLinkActive) {
                    NetworkHeadersDetailsView(viewModel: errorModel)
                }
            }

            NavigationLink.programmatic(isActive: $viewModel.isOriginalQueryItemsLinkActive) {
                viewModel.originalRequestQueryItems.map(NetworkHeadersDetailsView.init)
            }

            NavigationLink.programmatic(isActive: $viewModel.isRequestRawLinkActive, destination: {
                NetworkInspectorResponseView(viewModel: viewModel.requestBodyViewModel)
                    .backport.navigationTitle("Request")
            })

            NavigationLink.programmatic(isActive: $viewModel.isCurrentQueryItemsLinkActive) {
                viewModel.currentRequestQueryItems.map(NetworkHeadersDetailsView.init)
            }

            NavigationLink.programmatic(isActive: $viewModel.isResponseRawLinkActive, destination: {
                NetworkInspectorResponseView(viewModel: viewModel.responseBodyViewModel)
                    .backport.navigationTitle("Response")
            })

            NavigationLink.programmatic(isActive: $viewModel.isOriginalRequestHeadersLinkActive) {
                NetworkHeadersDetailsView(viewModel: viewModel.originalRequestHeaders)
            }

            NavigationLink.programmatic(isActive: $viewModel.isCurrentRequestHeadersLinkActive) {
                NetworkHeadersDetailsView(viewModel: viewModel.currentRequestHeaders)
            }

            if let responesHeaders = viewModel.responseHeaders {
                NavigationLink.programmatic(isActive: $viewModel.isResponseHeadearsRawLinkActive) {
                    NetworkHeadersDetailsView(viewModel: responesHeaders)
                }
            }
        }
        .frame(height: 0)
        .hidden()
        .backport.hideAccessibility()
    }
}

#if os(tvOS)
private let spacing: CGFloat = 20
#else
private let spacing: CGFloat? = nil
#endif

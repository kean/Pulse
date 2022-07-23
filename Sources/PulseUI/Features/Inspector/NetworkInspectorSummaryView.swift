// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

struct NetworkInspectorSummaryView: View {
    @ObservedObject var viewModel: NetworkInspectorSummaryViewModel

    var body: some View {
#if os(iOS) || os(macOS)
        ScrollView {
            VStack {
                contents
            }.padding()
        }.background(invisibleLinks)
#elseif os(watchOS)
        ScrollView {
            Spacer().frame(height: 24)
            VStack(spacing: 24) {
                contents
            }
        }.background(invisibleLinks)
#elseif os(tvOS)
        List {
            contents
        }
#endif
    }

#if os(iOS) || os(macOS)
    @ViewBuilder
    private var contents: some View {
        if let transfer = viewModel.transferModel {
            Spacer().frame(height: 12)
            NetworkInspectorTransferInfoView(viewModel: transfer)
            Spacer().frame(height: 20)
        }
        KeyValueSectionView(viewModel: viewModel.summaryModel)
        viewModel.errorModel.map(KeyValueSectionView.init)
        viewModel.timingDetailsModel.map(KeyValueSectionView.init)
        if let requestSummary = viewModel.requestSummary {
            Section(header: LargeSectionHeader(title: "Request")) {
                KeyValueSectionView(viewModel: requestSummary)
                KeyValueSectionView(viewModel: viewModel.requestHeaders, limit: 10)
                KeyValueSectionView(viewModel: viewModel.requestBodySection)
                viewModel.requestParameters.map(KeyValueSectionView.init)
            }
        }
        if let responseSummary = viewModel.responseSummary {
            Section(header: LargeSectionHeader(title: "Response")) {
                KeyValueSectionView(viewModel: responseSummary)
                KeyValueSectionView(viewModel: viewModel.responseHeaders, limit: 10)
                KeyValueSectionView(viewModel: viewModel.responseBodySection)
            }
        }
    }
#elseif os(watchOS)
    @ViewBuilder
    private var contents: some View {
        if let transfer = viewModel.transferModel {
            NetworkInspectorTransferInfoView(viewModel: transfer)
        }
        // Summary
        KeyValueSectionView(viewModel: viewModel.summaryModel)
        viewModel.errorModel.map(KeyValueSectionView.init)
        // HTTP Body
        KeyValueSectionView(viewModel: viewModel.requestBodySection)
        KeyValueSectionView(viewModel: viewModel.responseBodySection)
        // Timing
        viewModel.timingDetailsModel.map(KeyValueSectionView.init)
        // HTTTP Headers
        KeyValueSectionView(viewModel: viewModel.requestHeaders, limit: 10)
        KeyValueSectionView(viewModel: viewModel.responseHeaders, limit: 10)
    }
#elseif os(tvOS)
    var metrics: NetworkInspectorMetricsViewModel?

    @ViewBuilder
    private var contents: some View {
        makeKeyValueSection(viewModel: viewModel.summaryModel)
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
        if let timing = viewModel.timingDetailsModel, let metrics = metrics {
            NavigationLink(destination: NetworkInspectorMetricsView(viewModel: metrics).focusable(true)) {
                KeyValueSectionView(viewModel: timing)
            }
        }
        makeKeyValueSection(viewModel: viewModel.requestHeaders)
        if viewModel.responseSummary != nil {
            makeKeyValueSection(viewModel: viewModel.responseHeaders)
        }
    }

    func makeKeyValueSection(viewModel: KeyValueSectionViewModel) -> some View {
        NavigationLink(destination: KeyValueSectionView(viewModel: viewModel).focusable(true)) {
            KeyValueSectionView(viewModel: viewModel, limit: 5)
        }
    }
#endif

    private var invisibleLinks: some View {
        VStack {
            if let errorModel = viewModel.errorModel {
                NavigationLink.programmatic(isActive: $viewModel.isErrorRawLinkActive) {
                    NetworkHeadersDetailsView(viewModel: errorModel)
                }
            }

            NavigationLink.programmatic(isActive: $viewModel.isRequestRawLinkActive, destination: {
                NetworkInspectorResponseView(viewModel: viewModel.requestBodyViewModel)
            })

            NavigationLink.programmatic(isActive: $viewModel.isResponseRawLinkActive, destination: {
                NetworkInspectorResponseView(viewModel: viewModel.responseBodyViewModel)
            })

            NavigationLink.programmatic(isActive: $viewModel.isRequestHeadersLinkActive) {
                NetworkHeadersDetailsView(viewModel: viewModel.requestHeaders)
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

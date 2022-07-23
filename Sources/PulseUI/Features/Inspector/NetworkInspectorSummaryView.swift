// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(iOS) || os(watchOS) || os(macOS)

struct NetworkInspectorSummaryView: View {
    @ObservedObject var viewModel: NetworkInspectorSummaryViewModel

    var body: some View {
        ScrollView {
#if os(watchOS)
            Spacer().frame(height: 24)
            VStack(spacing: 24) {
                contents
            }
#else
            VStack {
                contents
            }.padding()
#endif
        }
        .background(linksView)
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
#endif

    private var linksView: some View {
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

#endif

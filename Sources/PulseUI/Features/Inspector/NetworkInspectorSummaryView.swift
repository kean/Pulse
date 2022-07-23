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
            VStack(spacing: 8) {
                contents
            }.padding()
            #endif
        }
    }

    @ViewBuilder
    private var contents: some View {
        #if !os(watchOS)
        if let transfer = viewModel.transferModel {
            Spacer().frame(height: 12)
            NetworkInspectorTransferInfoView(viewModel: transfer)
            Spacer().frame(height: 20)
        }
        #endif
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

        linksView

        #if !os(watchOS)
        Spacer()
        #endif
    }

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

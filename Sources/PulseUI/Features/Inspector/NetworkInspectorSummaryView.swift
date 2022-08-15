// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

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

    @ViewBuilder
    private var originalRequestSection: some View {
        Section(header: requestHeaderView) {
            VStack(spacing: 16) {
                viewModel.originalRequestSummary.map(KeyValueSectionView.init)
                viewModel.originalRequestQueryItems.map { KeyValueSectionView(viewModel: $0, limit: 10) }
                KeyValueSectionView(viewModel: viewModel.originalRequestHeaders, limit: 10)
                KeyValueSectionView(viewModel: viewModel.requestBodySection)
                viewModel.originalRequestParameters.map(KeyValueSectionView.init)
            }
        }
    }

    @ViewBuilder
    private var currentRequestSection: some View {
        Section(header: requestHeaderView) {
            VStack(spacing: 16) {
                viewModel.currentRequestSummary.map(KeyValueSectionView.init)
                viewModel.currentRequestQueryItems.map { KeyValueSectionView(viewModel: $0, limit: 10) }
                KeyValueSectionView(viewModel: viewModel.currentRequestHeaders, limit: 10)
                KeyValueSectionView(viewModel: viewModel.requestBodySection)
                viewModel.currentRequestParameters.map(KeyValueSectionView.init)
            }
        }
    }

    @ViewBuilder
    private var responseSection: some View {
        Section(header: LargeSectionHeader(title: "Response")) {
            VStack(spacing: 16) {
                viewModel.responseSummary.map(KeyValueSectionView.init)
                KeyValueSectionView(viewModel: viewModel.responseHeaders, limit: 10)
                KeyValueSectionView(viewModel: viewModel.responseBodySection)
            }
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
        viewModel.timingDetailsViewModel.map(KeyValueSectionView.init)
    }
#elseif os(tvOS)
    @ViewBuilder
    private var contents: some View {
        headerView

        NavigationLink(destination: KeyValueSectionView(viewModel: viewModel.summaryViewModel).focusable()) {
            summaryView
        }

        if let error = viewModel.errorModel {
            makeKeyValueSection(viewModel: error)
        }
        NavigationLink(destination: FileViewer(viewModel: viewModel.requestBodyViewModel).focusable()) {
            KeyValueSectionView(viewModel: viewModel.requestBodySection)
        }
        if viewModel.responseSummary != nil {
            NavigationLink(destination: FileViewer(viewModel: viewModel.responseBodyViewModel).focusable()) {
                KeyValueSectionView(viewModel: viewModel.responseBodySection)
            }
        }
        makeKeyValueSection(viewModel: viewModel.originalRequestHeaders)
        if viewModel.responseSummary != nil {
            makeKeyValueSection(viewModel: viewModel.responseHeaders)
        }
        if let timingDetailsViewModel = viewModel.timingDetailsViewModel, let timingViewModel = viewModel.timingViewModel {
            NavigationLink(destination: TimingView(viewModel: timingViewModel).focusable()) {
                KeyValueSectionView(viewModel: timingDetailsViewModel)
            }
        }
    }

    func makeKeyValueSection(viewModel: KeyValueSectionViewModel) -> some View {
        NavigationLink(destination: KeyValueSectionView(viewModel: viewModel).focusable()) {
            KeyValueSectionView(viewModel: viewModel, limit: 5)
        }
    }
#endif
    @ViewBuilder
    private var headerView: some View {
        if let transfer = viewModel.transferViewModel {
            makeTransferInfo(with: transfer)
        } else if let progress = viewModel.progressViewModel {
            ZStack {
                makeTransferInfo(with: .init(empty: true))
                    .hidden()
                    .backport.hideAccessibility()
                SpinnerView(viewModel: progress)
            }
        }
    }

    private func makeTransferInfo(with viewModel: NetworkInspectorTransferInfoViewModel) -> some View {
        NetworkInspectorTransferInfoView(viewModel: viewModel)
        #if os(watchOS)
            .padding(.top, 24)
        #else
            .padding(EdgeInsets(top: 12, leading: 0, bottom: 24, trailing: 0))
        #endif
    }

    private var summaryView: some View {
        let summaryViewModel = viewModel.summaryViewModel
        return VStack(spacing: 8) {
            HStack(spacing: spacing) {
                Text(summaryViewModel.title)
                Image(systemName: viewModel.statusImageName)
                    .foregroundColor(viewModel.tintColor)
                Spacer()
            }.font(.headline)

            KeyValueSectionView(viewModel: summaryViewModel)
                .hiddenTitle()
        }
    }

    private var links: some View {
        InvisibleNavigationLinks {
            if let errorModel = viewModel.errorModel {
                NavigationLink.programmatic(isActive: $viewModel.isErrorRawLinkActive) {
                    NetworkHeadersDetailsView(viewModel: errorModel)
                }
            }

#if os(iOS) || os(macOS)
            NavigationLink.programmatic(isActive: $viewModel.isOriginalQueryItemsLinkActive) {
                viewModel.originalRequestQueryItems.map(NetworkHeadersDetailsView.init)
            }
#endif

            NavigationLink.programmatic(isActive: $viewModel.isRequestRawLinkActive, destination: {
                FileViewer(viewModel: viewModel.requestBodyViewModel)
                    .backport.navigationTitle("Request")
            })

#if os(iOS) || os(macOS)
            NavigationLink.programmatic(isActive: $viewModel.isCurrentQueryItemsLinkActive) {
                viewModel.currentRequestQueryItems.map(NetworkHeadersDetailsView.init)
            }
#endif
            
            NavigationLink.programmatic(isActive: $viewModel.isResponseRawLinkActive, destination: {
                FileViewer(viewModel: viewModel.responseBodyViewModel)
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
    }
}

#if os(tvOS)
private let spacing: CGFloat = 20
#else
private let spacing: CGFloat? = nil
#endif

#if DEBUG
struct NetworkInspectorSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NetworkInspectorSummaryView(viewModel: .init(task: LoggerStore.preview.entity(for: .patchRepo)))
        }
    }
}
#endif

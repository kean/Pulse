// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleNetworkFiltersView: View {
    @ObservedObject var viewModel: ConsoleSearchViewModel

    @State private var isRedirectGroupExpanded = true
    @State private var isDomainsPickerPresented = false

#if os(iOS) || os(watchOS) || os(tvOS)
    var body: some View {
        Form { formContents }
#if os(iOS)
            .navigationBarItems(leading: buttonReset)
#endif
    }
#else
    var body: some View {
        ScrollView {
            formContents.frame(width: 320)
        }
    }
#endif
}

// MARK: - NetworkFiltersView (Contents)

extension ConsoleNetworkFiltersView {
    @ViewBuilder
    var formContents: some View {
#if os(tvOS) || os(watchOS)
        Section {
            buttonReset
        }
#endif
        ConsoleSharedFiltersView(viewModel: viewModel)
#if os(iOS) || os(macOS)
        if #available(iOS 15, *) {
            generalGroup
        }
#endif
        responseGroup
        domainsGroup
        networkingGroup
    }

    var buttonReset: some View {
        Button.destructive(action: viewModel.resetAll) { Text("Reset") }
            .disabled(!viewModel.isButtonResetEnabled)
    }
}

// MARK: - NetworkFiltersView (General)

#if os(iOS) || os(macOS)

@available(iOS 15, *)
extension ConsoleNetworkFiltersView {
    var generalGroup: some View {
        ConsoleFilterSection(
            header: { generalGroupHeader },
            content: { generalGroupContent }
        )
    }

    private var generalGroupHeader: some View {
        ConsoleFilterSectionHeader(icon: "line.horizontal.3.decrease.circle", title: "Filters", filter: $viewModel.criteria.network.custom)
    }

#if os(iOS)
    @ViewBuilder
    private var generalGroupContent: some View {
        customFilersList
        if !(viewModel.criteria.network.custom == .init()) {
            Button(action: { viewModel.criteria.network.custom.filters.append(.default) }) {
                Text("Add Filter").frame(maxWidth: .infinity)
            }
        }
    }
#elseif os(macOS)
    @ViewBuilder
    private var generalGroupContent: some View {
        VStack {
            customFilersList
        }.padding(.leading, -8)

        if !(viewModel.criteria.network.custom == .init()) {
            Button(action: { viewModel.criteria.network.custom.filters.append(.default) }) {
                Image(systemName: "plus.circle")
            }.padding(.top, 6)
        }
    }
#endif

    @ViewBuilder var customFilersList: some View {
        ForEach($viewModel.criteria.network.custom.filters) { filter in
            ConsoleCustomNetworkFilterView(filter: filter, onRemove: viewModel.criteria.network.custom.filters.count > 1  ? { viewModel.remove(filter.wrappedValue) } : nil)
        }
    }
}

#endif

// MARK: - NetworkFiltersView (Response)

extension ConsoleNetworkFiltersView {
    var responseGroup: some View {
        ConsoleFilterSection(
            header: { responseGroupHeader },
            content: { responseGroupContent }
        )
    }

    private var responseGroupHeader: some View {
        ConsoleFilterSectionHeader(icon: "arrow.down.circle", title:  "Response", filter: $viewModel.criteria.network.response)
    }

    @ViewBuilder
    private var responseGroupContent: some View {
#if os(iOS) || os(macOS)
        ConsoleFiltersStatusCodeCell(selection: $viewModel.criteria.network.response.statusCode.range)
        ConsoleFiltersDurationCell(selection: $viewModel.criteria.network.response.duration)
        ConsoleFiltersResponseSizeCell(selection: $viewModel.criteria.network.response.responseSize)
#endif
        ConsoleFiltersContentTypeCell(selection: $viewModel.criteria.network.response.contentType.contentType)
    }
}

// MARK: - NetworkFiltersView (Domains)

extension ConsoleNetworkFiltersView {
    var domainsGroup: some View {
        ConsoleFilterSection(
            header: { domainsGroupHeader },
            content: { domainsGroupContent }
        )
    }

    private var domainsGroupHeader: some View {
        ConsoleFilterSectionHeader(icon: "server.rack", title: "Hosts", filter: $viewModel.criteria.network.host)
    }

    @ViewBuilder
    private var domainsGroupContent: some View {
        makeDomainPicker(limit: 4)
        if viewModel.domains.objects.count > 4 {
            domainsShowAllButton
        }
    }

#if os(macOS)
    private var domainsShowAllButton: some View {
        HStack {
            Spacer()
            Button(action: { isDomainsPickerPresented = true }) {
                Text("Show All")
            }
            .padding(.top, 6)
            .popover(isPresented: $isDomainsPickerPresented) {
                domainsPickerView.frame(width: 380, height: 420)
            }
            Spacer()
        }
    }

    private func makeDomainPicker(limit: Int? = nil) -> some View {
        var domains = viewModel.domains.objects.map(\.value)
        if let limit = limit {
            domains = Array(domains.prefix(limit))
        }
        return ForEach(domains, id: \.self) { domain in
            Toggle(domain, isOn: viewModel.binding(forDomain: domain))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
#else
    private var domainsShowAllButton: some View {
        NavigationLink(destination: { domainsPickerView }) {
            Text("Show All")
        }
    }

    private func makeDomainPicker(limit: Int? = nil) -> some View {
        var domains = viewModel.domains.objects.map(\.value)
        if let limit = limit {
            domains = Array(domains.prefix(limit))
        }
        return ForEach(domains, id: \.self) { domain in
            Checkbox(domain, isOn: viewModel.binding(forDomain: domain))
                .lineLimit(4)
        }
    }
#endif

    // TODO: Add search
    private var domainsPickerView: some View {
        List {
            Button("Deselect All") {
                viewModel.criteria.network.host.ignoredHosts = Set(viewModel.domains.objects.map(\.value))
            }
            makeDomainPicker()
        }
        .inlineNavigationTitle("Select Hosts")
    }
}

// MARK: - NetworkFiltersView (Networking)

extension ConsoleNetworkFiltersView {
    var networkingGroup: some View {
        ConsoleFilterSection(
            header: { networkingGroupHeader },
            content: { networkingGroupContent }
        )
    }

    private var networkingGroupHeader: some View {
        ConsoleFilterSectionHeader(icon: "arrowshape.zigzag.right", title: "Networking", filter: $viewModel.criteria.network.networking)
    }

    @ViewBuilder
    private var networkingGroupContent: some View {
        ConsoleFiltersTaskTypeCell(selection: $viewModel.criteria.network.networking.taskType)
        ConsoleFiltersResponseSourceCell(selection: $viewModel.criteria.network.networking.source)
        ConsoleFiltersToggleCell(title: "Redirect", isOn: $viewModel.criteria.network.networking.isRedirect)
    }
}

#if DEBUG
struct NetworkFiltersView_Previews: PreviewProvider {
    static var previews: some View {
#if os(macOS)
        ConsoleNetworkFiltersView(viewModel: .init(store: .mock))
            .previewLayout(.fixed(width: 320, height: 900))
#else
        NavigationView {
            ConsoleNetworkFiltersView(viewModel: .init(store: .mock))
        }.navigationViewStyle(.stack)
#endif
    }
}
#endif

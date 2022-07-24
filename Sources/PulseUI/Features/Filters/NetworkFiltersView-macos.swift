// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(macOS)

struct NetworkFiltersView: View {
    @ObservedObject var viewModel: NetworkSearchCriteriaViewModel

    @AppStorage("networkFilterIsParametersExpanded") var isParametersExpanded = true
    @AppStorage("networkFilterIsResponseExpanded") var isResponseGroupExpanded = true
    @AppStorage("networkFilterIsTimePeriodExpanded") var isTimePeriodExpanded = true
    @AppStorage("networkFilterIsDomainsGroupExpanded") var isDomainsGroupExpanded = true
    @AppStorage("networkFilterIsDurationGroupExpanded") var isDurationGroupExpanded = true
    @AppStorage("networkFilterIsContentTypeGroupExpanded") var isContentTypeGroupExpanded = true
    @AppStorage("networkFilterIsRedirectGroupExpanded") var isRedirectGroupExpanded = true

    @State var isDomainsPickerPresented = false

    var body: some View {
        ScrollView {
            VStack(spacing: Filters.formSpacing) {
                VStack(spacing: 6) {
                    HStack {
                        Text("FILTERS")
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Reset") { viewModel.resetAll() }
                        .disabled(!viewModel.isButtonResetEnabled)
                    }
                    Divider()
                }.padding(.top, 6)
                
                generalGroup
                responseGroup
                durationGroup
                timePeriodGroup
                domainsGroup
                networkingGroup
            }.padding(Filters.formPadding)
        }
    }

    // MARK: - General
    
    private var generalGroup: some View {
        DisclosureGroup(isExpanded: $isParametersExpanded, content: {
            VStack {
                ForEach(viewModel.filters) { filter in
                    CustomNetworkFilterView(filter: filter, onRemove: {
                        viewModel.removeFilter(filter)
                    })
                }
            }
            .padding(.leading, 4)
            .padding(.top, Filters.contentTopInset)
            Button(action: viewModel.addFilter) {
                Image(systemName: "plus.circle")
            }
        }, label: {
            FilterSectionHeader(
                icon: "line.horizontal.3.decrease.circle", title: "General",
                color: .yellow,
                reset: { viewModel.resetFilters() },
                isDefault: viewModel.filters.count == 1 && viewModel.filters[0].isDefault,
                isEnabled: $viewModel.criteria.isFiltersEnabled
            )
        })
    }
}

#if DEBUG
struct NetworkFiltersPanelPro_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NetworkFiltersView(viewModel: makeMockViewModel())
                .previewLayout(.fixed(width: Filters.preferredWidth - 15, height: 940))
        }
    }
}

private func makeMockViewModel() -> NetworkSearchCriteriaViewModel {
    let viewModel = NetworkSearchCriteriaViewModel()
    viewModel.setInitialDomains(["api.github.com", "github.com", "apple.com", "google.com", "example.com"])
    return viewModel

}
#endif

#endif

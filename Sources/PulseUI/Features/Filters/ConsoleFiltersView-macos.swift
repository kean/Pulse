// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(macOS)

struct ConsoleFiltersView: View {
    @ObservedObject var viewModel: ConsoleSearchCriteriaViewModel
    
    @AppStorage("networkFilterIsParametersExpanded") var isGeneralSectionExpanded = true
    @AppStorage("consoleFiltersIsLevelsSectionExpanded") var isLevelsSectionExpanded = true
    @AppStorage("consoleFiltersIsLabelsExpanded") var isLabelsSectionExpanded = false
    @AppStorage("consoleFiltersIsTimePeriodExpanded") var isTimePeriodSectionExpanded = true

    var body: some View {
        ScrollView {
            VStack(spacing: Filters.formSpacing) {
                VStack(spacing: 6) {
                    HStack {
                        Text("FILTERS")
                            .foregroundColor(.secondary)
                        Spacer()
                        buttonReset
                    }
                    Divider()
                }
                .padding(.top, 6)

                formContents
            }.padding(Filters.formPadding)
        }
    }
}

#if DEBUG
struct ConsoleFiltersPanelPro_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ConsoleFiltersView(viewModel: makeMockViewModel())
                .previewLayout(.fixed(width: Filters.preferredWidth - 15, height: 700))
        }
    }
}

private func makeMockViewModel() -> ConsoleSearchCriteriaViewModel {
    let viewModel = ConsoleSearchCriteriaViewModel()
    viewModel.setInitialLabels(["network", "auth", "application", "general", "navigation"])
    return viewModel
}
#endif

#endif

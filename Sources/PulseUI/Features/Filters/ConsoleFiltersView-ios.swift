// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS)

struct ConsoleFiltersView: View {
    @ObservedObject var viewModel: ConsoleSearchCriteriaViewModel

    @State var isGeneralSectionExpanded = true
    @State var isLevelsSectionExpanded = true
    @State var isLabelsSectionExpanded = false
    @State var isTimePeriodSectionExpanded = true

    @State var isAllLabelsShown = false

    @Binding var isPresented: Bool

    var body: some View {
        Form { formContents }
            .navigationBarTitle("Filters", displayMode: .inline)
            .navigationBarItems(leading: buttonClose, trailing: buttonReset)
    }

    private var buttonClose: some View {
        Button("Close") { isPresented = false }
    }
}

struct ConsoleFiltersPanelPro_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                ConsoleFiltersView(viewModel: makeMockViewModel(), isPresented: .constant(true))
            }
        }
    }
}

private func makeMockViewModel() -> ConsoleSearchCriteriaViewModel {
    let viewModel = ConsoleSearchCriteriaViewModel()
    viewModel.setInitialLabels(["network", "auth", "application", "general", "navigation"])
    return viewModel
}

#endif

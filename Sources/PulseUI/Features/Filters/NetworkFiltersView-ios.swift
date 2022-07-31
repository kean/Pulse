// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS)

struct NetworkFiltersView: View {
    @ObservedObject var viewModel: NetworkSearchCriteriaViewModel

    @State var isGeneralGroupExpanded = true
    @State var isResponseGroupExpanded = true
    @State var isTimePeriodExpanded = true
    @State var isDomainsGroupExpanded = true
    @State var isDurationGroupExpanded = true
    @State var isContentTypeGroupExpanded = true
    @State var isRedirectGroupExpanded = true

    @Binding var isPresented: Bool

    var body: some View {
        Form {
            formContents
        }
        .navigationBarTitle("Filters", displayMode: .inline)
        .navigationBarItems(leading: buttonClose, trailing: buttonReset)
    }

    private var buttonClose: some View {
        Button("Close") { isPresented = false }
    }
}

#if DEBUG
struct NetworkFiltersView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NetworkFiltersView(viewModel: makeMockViewModel(), isPresented: .constant(true))
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

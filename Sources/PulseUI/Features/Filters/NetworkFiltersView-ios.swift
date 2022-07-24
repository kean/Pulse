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
            if #available(iOS 14.0, *) {
                generalGroup
            }
            responseGroup
            if #available(iOS 14.0, *) {
                durationGroup
            }
            timePeriodGroup
            domainsGroup
            networkingGroup
        }
        .navigationBarTitle("Filters", displayMode: .inline)
        .navigationBarItems(leading: buttonClose, trailing: buttonReset)
    }

    private var buttonClose: some View {
        Button("Close") { isPresented = false }
    }

    private var buttonReset: some View {
        Button("Reset") { viewModel.resetAll() }
            .disabled(!viewModel.isButtonResetEnabled)
    }
}

struct NetworkFiltersView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                NetworkFiltersView(viewModel: .init(), isPresented: .constant(true))
            }
        }
    }
}

#endif

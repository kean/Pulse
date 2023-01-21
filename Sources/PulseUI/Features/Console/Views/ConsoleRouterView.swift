// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

struct ConsoleRouterView: View {
    let viewModel: ConsoleViewModel
    @ObservedObject var router: ConsoleRouter

    var body: some View {
        Text("")
            .invisible()
            .sheet(item: $router.shareItems, content: ShareView.init)
            .sheet(isPresented: $router.isShowingAsText) { destinationTextView }
            .sheet(isPresented: $router.isShowingFilters) { destinationFilters }
    }

    private var destinationTextView: some View {
        NavigationView {
            ConsoleTextView(entities: viewModel.list.entitiesSubject) {
                viewModel.router.isShowingAsText = false
            }
        }
    }

    private var destinationFilters: some View {
        NavigationView {
            ConsoleSearchCriteriaView(viewModel: viewModel.searchCriteriaViewModel)
                .inlineNavigationTitle("Filters")
                .navigationBarItems(trailing: Button("Done") {
                    viewModel.router.isShowingFilters = false
                })
        }
    }
}

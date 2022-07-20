// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS)

struct ConsoleFiltersLabelsPickerView: View {
    @ObservedObject var viewModel: ConsoleSearchCriteriaViewModel

    @State private var searchText = ""

    var body: some View {
        if #available(iOS 15.0, *) {
            form
#if os(iOS)
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
#endif
        } else {
            form
        }
    }

    @ViewBuilder
    private var form: some View {
        Form {
            Button(viewModel.bindingForTogglingAllLabels.wrappedValue ? "Disable All" : "Enable All", action: { viewModel.bindingForTogglingAllLabels.wrappedValue.toggle() })
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.accentColor)

            ForEach(labels, id: \.self) { item in
                Toggle(item.capitalized, isOn: viewModel.binding(forLabel: item))
            }
        }
#if os(iOS)
        .navigationBarTitle("Labels")
#endif
    }

    private var labels: [String] {
        if searchText.isEmpty {
            return viewModel.allLabels
        } else {
            return viewModel.allLabels.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
}

struct ConsoleFiltersView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConsoleFiltersLabelsPickerView(viewModel: .init())
        }
    }
}

#endif

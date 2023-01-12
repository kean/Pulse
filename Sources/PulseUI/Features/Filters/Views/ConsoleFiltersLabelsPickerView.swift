// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS) || os(tvOS) || os(watchOS)

struct ConsoleFiltersLabelsPickerView: View {
    @ObservedObject var viewModel: ConsoleSearchCriteriaViewModel
    @ObservedObject var labels: ManagedObjectsObserver<LoggerLabelEntity>
    @State private var searchText = ""

    init(viewModel: ConsoleSearchCriteriaViewModel) {
        self.viewModel = viewModel
        self.labels = viewModel.labels
    }

    var body: some View {
        if #available(iOS 15, tvOS 15, *) {
            form
#if os(iOS)
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
#else
                .searchable(text: $searchText)
#endif
        } else {
            form
        }
    }

    @ViewBuilder
    private var form: some View {
        Form {
            Button(viewModel.bindingForTogglingAllLabels.wrappedValue ? "Disable All" : "Enable All") { viewModel.bindingForTogglingAllLabels.wrappedValue.toggle()
            }
#if !os(watchOS)
            .foregroundColor(.accentColor)
#endif

            ForEach(allLabels, id: \.self) { item in
                Checkbox(item.capitalized, isOn: viewModel.binding(forLabel: item))
            }
        }
        .navigationBarTitle("Labels")
    }

    private var allLabels: [String] {
        let labels = self.labels.objects.map(\.name)
        return searchText.isEmpty ? labels : labels.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
}

#if DEBUG
struct ConsoleFiltersLabelsPickerView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConsoleFiltersLabelsPickerView(viewModel: .init(store: .mock))
        }
    }
}
#endif

#endif

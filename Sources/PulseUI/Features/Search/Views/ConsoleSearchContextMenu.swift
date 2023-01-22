import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS)

@available(iOS 15, *)
struct ConsoleSearchContextMenu: View {
    @ObservedObject var viewModel: ConsoleSearchViewModel

    @State private var isShowingAsText = false
    @State private var shareItems: ShareItems?
    @State private var isShowingShareStore = false

    var body: some View {
        Menu {
            Section {
                Button(action: { isShowingAsText.toggle() }) {
                    if isShowingAsText {
                        Label("View as List", systemImage: "list.bullet.rectangle.portrait")
                    } else {
                        Label("View as Text", systemImage: "text.quote")
                    }
                }
            }
            Section {
                Menu(content: {
                    ForEach(ConsoleSearchScope.allCases, id: \.self) {
                        Toggle($0.fullTitle, isOn: .constant(true))
                    }

                }) {
                    Text("Search Scopes")
                }
            }
            Section {
                StringSearchOptionsMenu(options: $viewModel.options)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
        }
        .sheet(item: $shareItems, content: ShareView.init)
        .sheet(isPresented: $isShowingAsText) {
            NavigationView {
                ConsoleTextView(entities: .init(viewModel.results.map(\.entity))) {
                    isShowingAsText = false
                }
            }
        }
    }
}
#endif

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
                Menu(content: { shareMenu }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
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

    @ViewBuilder
    private var shareMenu: some View {
        Button(action: { share(as: .plainText) }) {
            Label("Share as Text", systemImage: "square.and.arrow.up")
        }
        Button(action: { share(as: .html) }) {
            Label("Share as HTML", systemImage: "square.and.arrow.up")
        }
    }

    private func share(as output: ShareOutput) {
        viewModel.prepareForSharing(as: output) { item in
            shareItems = item
        }
    }
}
#endif

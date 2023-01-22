import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS)

@available(iOS 15, *)
struct ConsoleSearchContextMenu: View {
    @ObservedObject var viewModel: ConsoleSearchViewModel

    var body: some View {
        Menu {
            StringSearchOptionsMenu(options: $viewModel.options)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
        }
    }
}
#endif

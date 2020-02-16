// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Herald
import Combine

struct ConsoleView: View {
    @FetchRequest<MessageEntity>(sortDescriptors: [NSSortDescriptor(keyPath: \MessageEntity.created, ascending: false)], predicate: nil)
    var messages: FetchedResults<MessageEntity>

    @ObservedObject var model: ConsoleMessagesListViewModel

    var body: some View {
        NavigationView {
            VStack {
                SearchBar(title: "Search", text: $model.searchText)
                    .padding()
                List {
                    ForEach(model.messages, id: \.objectID) { messsage -> ConsoleMessageView in
                        print("render \(messsage)")
                        return ConsoleMessageView(model: .init(message: messsage))
                    }
                }
            }
            .navigationBarTitle(Text("Console"))
        }
    }
}

struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        let store = mockMessagesStore
        return Group {
            ConsoleView(model: ConsoleMessagesListViewModel(context: store.viewContext))
            ConsoleView(model: ConsoleMessagesListViewModel(context: store.viewContext))
                .environment(\.colorScheme, .dark)
        }
    }
}

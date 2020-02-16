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

    @State private var searchText: String = ""

    var body: some View {
        NavigationView {
            VStack {
                SearchBar(title: "Search", text: $searchText)
                    .padding()
                List {
                    ForEach(messages, id: \.objectID) {
                        ConsoleMessageView(model: .init(message: $0))
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
            ConsoleView()
            ConsoleView()
                .environment(\.colorScheme, .dark)
        }.environment(\.managedObjectContext, store.viewContext)
    }
}

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

    var body: some View {
        NavigationView {
            List {
                ForEach(messages, id: \.objectID) {
                    ConsoleMessageView(model: .init(message: $0))
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

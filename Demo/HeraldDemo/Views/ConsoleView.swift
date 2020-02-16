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
        List(messages, id: \.self) { message in
            ConsoleMessageView(model: .init(message: message))
        }
    }
}

struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        let store = mockMessagesStore
        return ConsoleView()
            .environment(\.managedObjectContext, store.viewContext)
    }
}

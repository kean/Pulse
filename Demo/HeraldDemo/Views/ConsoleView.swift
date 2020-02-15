// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Herald

struct ConsoleView: View {
    private var request: FetchRequest<MessageEntity>!

    @FetchRequest<MessageEntity>(entity: MessageEntity.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \MessageEntity.created, ascending: false)]) var messages: FetchedResults<MessageEntity>

    var body: some View {
        List(messages, id: \.self) { message in
            ConsoleMessageView(model: .init(message: message))
        }.listRowInsets(nil)
    }
}

struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        let store = mockMessagesStore
        return ConsoleView()
            .environment(\.managedObjectContext, store.viewContext)
    }
}

// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Herald

struct ConsoleView: View {
    @ObservedObject var messages: FetchedEntities<MessageEntity>

    var body: some View {
        List(messages, id: \.self) { message in
            Text(message.text)
        }
    }
}

struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        let store = mockMessagesStore
        let messages = FetchedEntities<MessageEntity>(context: store.viewContext, sortedBy: \.created)
        return ConsoleView(messages: messages)
    }
}

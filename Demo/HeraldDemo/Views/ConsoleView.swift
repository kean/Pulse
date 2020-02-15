// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Herald

struct ConsoleView: View {
    var messages: [Logger.Message]

    var body: some View {
        Text("Placeholder")
//        List(messages) {
//            ConsoleMessageView(model: .init(message: $0))
//        }
    }
}

struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleView(messages: [])
    }
}

//
// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

package struct PinView: View {
    private var message: LoggerMessageEntity?
    @State private var isPinned = false

    package init(message: LoggerMessageEntity?) {
        self.message = message
    }

    package init(task: NetworkTaskEntity) {
        self.init(message: task.message)
    }

    package var body: some View {
        if let message = message {
            Image(systemName: "pin")
                .font(.footnote)
                .foregroundColor(.pink)
                .opacity(isPinned ? 1 : 0)
                .frame(width: 8, height: 8)
                .onReceive(message.publisher(for: \.isPinned).removeDuplicates()) {
                    isPinned = $0
                }
        }
    }
}

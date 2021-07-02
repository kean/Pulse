// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import Cocoa
import PulseUI
import SwiftUI
import Combine

struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(before: .newItem) {
            Button("Open", action: openDocument).keyboardShortcut("o")
            Menu("Open Recent") {
                ForEach(NSDocumentController.shared.recentDocumentURLs, id: \.self) { url in
                    Button(action: { NSWorkspace.shared.open(url) }, label: {
                        Text(url.lastPathComponent)
                    })
                }
            }
        }
    }
}

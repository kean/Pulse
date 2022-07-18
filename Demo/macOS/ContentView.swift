// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Your app here")
            .padding()
            .frame(width: 400, height: 300)
            .toolbar {
                Button("Logs", action: showLogs)
            }
    }
}

private func showLogs() {
    let window = NSWindow(
        contentRect: .init(origin: .zero, size: .init(width: 300, height: 450)),
        styleMask: [.closable],
        backing: .buffered,
        defer: false
    )
    window.title = "Logs"
    window.isOpaque = false
    window.center()
    window.isMovableByWindowBackground = true
    window.backgroundColor = NSColor(calibratedHue: 0, saturation: 1.0, brightness: 0, alpha: 0.7)
    window.contentViewController = NSHostingController(rootView: Text("test").frame(width: 300, height: 300))
    window.makeKeyAndOrderFront(nil)
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseUI

struct ContentView: View {
    var body: some View {
        SettingsView()
            .frame(width: 300, height: 300)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

//
//  ContentView.swift
//  Pulse watchOS WatchKit Extension
//
//  Created by Alexander Grebenyuk on 08.03.2021.
//  Copyright © 2021 kean. All rights reserved.
//

import SwiftUI
import PulseCore
import PulseUI

struct ContentView: View {
    var body: some View {
        ConsoleView(store: .mock)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

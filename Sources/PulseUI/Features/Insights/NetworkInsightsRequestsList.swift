// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS)
struct NetworkInsightsRequestsList: View {
    let tasks: [NetworkTaskEntity]

    public var body: some View {
        List {
            ForEach(tasks, id: \.objectID, content: ConsoleEntityCell.init)
        }.listStyle(.plain)
    }
}
#endif

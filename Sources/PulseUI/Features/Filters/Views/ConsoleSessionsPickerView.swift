// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleSessionsPickerView: View {
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \LoggerSessionEntity.createdAt, ascending: false)])
    private var sessions: FetchedResults<LoggerSessionEntity>

    @State var selection: Set<UUID> = []

    var body: some View {
        ConsoleSearchListSelectionView(
            title: "Sessions",
            items: sessions,
            id: \.id,
            selection: $selection,
            description: \.formattedDate,
            label: { Text($0.formattedDate) }
        )
    }
}

struct Previews_ConsoleSessionsPickerView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            ConsoleSessionsPickerView()
        }
        .injectingEnvironment(.init(store: .mock))
    }
}

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleSessionsPickerView: View {
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \LoggerSessionEntity.createdAt, ascending: false)])
    private var sessions: FetchedResults<LoggerSessionEntity>

    @Binding var selection: Set<UUID>

    var body: some View {
        ConsoleSearchListSelectionView(
            title: "Sessions",
            items: sessions,
            id: \.id,
            selection: $selection,
            description: \.formattedDate,
            label: ConsoleSessionCell.init,
            limit: 3
        )
    }
}

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct InfoRow: View {
    let title: String
    let details: String?

    var body: some View {
        HStack {
            Text(title)
                .lineLimit(1)
            Spacer()
            if let details = details {
                Text(details)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct KeyValueRow: Identifiable {
    let id: Int
    let item: (String, String?)

    var title: String { item.0 }
    var details: String? { item.1 }
}

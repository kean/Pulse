// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI

package struct InfoRow: View {
    package let title: String
    package let details: String?

    package init(title: String, details: String?) {
        self.title = title
        self.details = details
    }

    package var body: some View {
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

package struct KeyValueRow: Identifiable {
    package let id: Int
    package let item: (String, String?)

    package var title: String { item.0 }
    package var details: String? { item.1 }

    package init(id: Int, item: (String, String?)) {
        self.id = id
        self.item = item
    }
}

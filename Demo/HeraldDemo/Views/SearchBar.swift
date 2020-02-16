// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import SwiftUI

struct SearchBar: View {
    let title: String
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").opacity(0.33)
            TextField(title, text: $text)
            if !text.isEmpty { buttonClear }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    private var buttonClear: some View {
        Button(action: { self.text = "" }) {
            Image(systemName: "xmark.circle.fill")
        }.foregroundColor(Color(.systemGray3))
    }
}

struct SearchBar_Previews: PreviewProvider {
    private struct SearchPreview: View {
        @State private var text: String = ""

        var body: some View {
            SearchBar(title: "Search", text: $text)
        }
    }

    static var previews: some View {
        SearchPreview()
            .previewLayout(.sizeThatFits)
    }
}

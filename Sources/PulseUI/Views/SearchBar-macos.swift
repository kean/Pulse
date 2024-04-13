// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI
import Combine

struct SearchBar: View {
    private let title: String
    private let imageName: String
    @Binding private var text: String

    init(title: String,
         imageName: String = "magnifyingglass",
         text: Binding<String>) {
        self.title = title
        self.imageName = imageName
        self._text = text
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: imageName)
                .foregroundColor(.secondary)
                .padding(.leading, 6)
            TextField(title, text: $text)
                .textFieldStyle(.plain)
                .frame(height: 22)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }
        }
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(.separator, lineWidth: 1)
        )
    }
}

#if DEBUG
struct Previews_SearchBar_macos_Previews: PreviewProvider {
    static var previews: some View {
        SearchBarDemo().padding()
    }
}

private struct SearchBarDemo: View {
    @State var value = ""

    var body: some View {
        SearchBar(title: "Search", text: $value)
    }
}
#endif

#endif

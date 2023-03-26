// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct DocumentCell: View {
    let url: URL

    var body: some View {
        Button(action: { NSWorkspace.shared.open(url) }, label: {
            let path = url.path.replacingOccurrences(of: "/Users/\(NSUserName())", with: "~", options: .anchored, range: nil)
            HStack {
                Image(systemName: "doc")
                    .font(.system(size: 20))
                    .foregroundColor(Color.accentColor)
                    .frame(width: 30, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text(url.lastPathComponent)
                        .lineLimit(1)
                    Text(path)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        })
        .help(url.path())
        .buttonStyle(.plain)
    }
}

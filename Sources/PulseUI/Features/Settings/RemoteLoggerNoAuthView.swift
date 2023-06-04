// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct RemotLoggerNoAuthView: View {
    var body: some View {
        HStack {
            Text(Image(systemName: "xmark.octagon.fill"))
            Text("Missing .plist file configuration")
        }
        .foregroundColor(.red)

        VStack(alignment: .leading, spacing: 16) {
            Text("Add the following to the app’s plist file to allow it to use [local networking](https://kean-docs.github.io/pulse/documentation/pulse/gettingstarted):")
            Text(plistContents)
                .font(.system(.footnote, design: .monospaced))
                .padding(8)
                .background(Color.separator.opacity(0.2))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.separator, lineWidth: 0.5)
                )
#if os(iOS)
            HStack {
                Spacer()
                Button("Copy") {
                    UXPasteboard.general.string = plistContents
                }
                .foregroundColor(.accentColor)
                .buttonStyle(.plain)
            }
#endif
        }
    }
}

private let plistContents = """
<key>NSLocalNetworkUsageDescription</key>
<string>Debugging purposes</string>
<key>NSBonjourServices</key>
<array>
  <string>_pulse._tcp</string>
</array>
"""

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct NetworkMenuCell: View {
    let icon: String
    let tintColor: Color
    let title: String
    var details: String = ""

    var body: some View {
#if os(watchOS)
        HStack {
            HStack {
                Text(title)
                Spacer()
                Text(details).foregroundColor(.secondary)
            }
        }
#elseif os(tvOS)
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text(details).foregroundColor(.secondary)
        }
#elseif os(macOS)
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text(details).foregroundColor(.secondary)
        }.padding(.vertical, 1)
#else
        HStack {
            Image(systemName: icon)
                .foregroundColor(tintColor)
                .font(.system(size: 20))
                .frame(width: 27, alignment: .center)
            Text(title)
            Spacer()
            Text(details).foregroundColor(.secondary)
        }
#endif
    }
}

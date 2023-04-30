// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import SwiftUI
import CoreData
import Combine

#if os(iOS) || os(macOS)

@available(iOS 15, macOS 13, *)
struct SessionPickerView: View {
    @Binding var selection: Set<UUID>

    var body: some View {
        SessionListView(selection: $selection, sharedSessions: .constant(nil))
#if os(iOS)
            .environment(\.editMode, .constant(.active))
            .inlineNavigationTitle("Sessions")
#endif
    }
}

#endif

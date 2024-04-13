// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import SwiftUI
import CoreData
import Combine

#if os(iOS) || os(macOS) || os(visionOS)

@available(iOS 15, macOS 13, visionOS 1.0, *)
struct SessionPickerView: View {
    @Binding var selection: Set<UUID>

    var body: some View {
        SessionListView(selection: $selection, sharedSessions: .constant(nil))
#if os(iOS) || os(visionOS)
            .environment(\.editMode, .constant(.active))
            .inlineNavigationTitle("Sessions")
#endif
    }
}

#endif

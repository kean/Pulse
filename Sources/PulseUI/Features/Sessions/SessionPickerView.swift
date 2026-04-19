// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import SwiftUI
import CoreData
import Combine

#if os(iOS) || os(visionOS)

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct SessionPickerView: View {
    @Binding var selection: Set<UUID>

    var body: some View {
        SessionListView(selection: $selection, sharedSessions: .constant(nil))
            .environment(\.editMode, .constant(.active))
            .inlineNavigationTitle("Sessions")
    }
}

#endif

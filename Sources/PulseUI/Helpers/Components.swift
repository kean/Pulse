// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct Components {
    static var makeSessionPicker: ((_ selection: Binding<Set<UUID>>) -> AnyView) = {
        AnyView(SessionPickerView(selection: $0))
    }
}

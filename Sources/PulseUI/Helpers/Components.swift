// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct Components {
    @available(iOS 15, macOS 13, visionOS 1.0, *)
    static func makeSessionPicker(selection: Binding<Set<UUID>>) -> some View {
        SessionPickerView(selection: selection)
    }

    static func makeRichTextView(string: NSAttributedString) -> some View {
        RichTextView(viewModel: .init(string: string))
    }

    static func makeConsoleEntityCell(entity: NSManagedObject) -> some View {
        ConsoleEntityCell(entity: entity)
    }

    static func makePinView(for task: NetworkTaskEntity) -> some View {
        EmptyView()
    }

    static func makePinView(for message: LoggerMessageEntity) -> some View {
        EmptyView()
    }
}

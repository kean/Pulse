// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData

struct Components {
#if os(iOS) || os(macOS) || os(visionOS)
    @available(iOS 15, macOS 13, visionOS 1, *)
    static func makeSessionPicker(selection: Binding<Set<UUID>>) -> some View {
        SessionPickerView(selection: selection)
    }
#endif

    static func makeRichTextView(string: NSAttributedString) -> some View {
        RichTextView(viewModel: .init(string: string))
    }

    @available(iOS 15, macOS 13, visionOS 1, *)
    static func makeConsoleEntityCell(entity: NSManagedObject) -> some View {
#if os(macOS)
        EmptyView()
#else
        ConsoleEntityCell(entity: entity)
#endif
    }

    static func makePinView(for task: NetworkTaskEntity) -> some View {
        EmptyView()
    }

    static func makePinView(for message: LoggerMessageEntity) -> some View {
        EmptyView()
    }
}

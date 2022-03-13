// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS) || os(macOS)

#if os(iOS)
import UIKit

@available(iOS 13.0, *)
struct ShareView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    private let cleanup: () -> Void

    // TODO: remove this variant
    init(activityItems: [Any]) {
        self.activityItems = activityItems
        self.cleanup = {}
    }

    init(_ items: ShareItems) {
        self.activityItems = items.items
        self.cleanup = items.cleanup
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<ShareView>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        controller.completionWithItemsHandler = { _, _, _, _ in
            cleanup()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ShareView>) {
    }
}
#endif

#if os(macOS)
import AppKit

@available(iOS 13.0, *)
struct ShareView: NSViewRepresentable {
    @Binding var isPresented: Bool
    var activityItems: () -> [Any]

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if isPresented {
            let picker = NSSharingServicePicker(items: activityItems())
            picker.delegate = context.coordinator

            DispatchQueue.main.async {
                picker.show(relativeTo: .zero, of: nsView, preferredEdge: .minY)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(owner: self)
    }

    class Coordinator: NSObject, NSSharingServicePickerDelegate {
        let owner: ShareView

        init(owner: ShareView) {
            self.owner = owner
        }

        func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
            sharingServicePicker.delegate = nil
            self.owner.isPresented = false
        }
    }
}

struct ShareMenuContent: View {
    let items: () -> [Any]
    @ObservedObject var model: ShareMenuContentViewModel

    init(model: ShareMenuContentViewModel, items: @autoclosure @escaping () -> [Any]) {
        self.model = model
        self.items = items
    }

    var body: some View {
        ForEach(model.services, id: \.title) { service in
            Button(action: { service.perform(withItems: self.items()) }) {
                Image(nsImage: service.image)
                Text(service.title)
            }
        }
    }
}

final class ShareMenuContentViewModel: ObservableObject {
    @Published private(set) var services: [NSSharingService] = []

    init(preview: [Any]) {
        DispatchQueue.global().async {
            let services = NSSharingService.sharingServices(forItems: preview)
            DispatchQueue.main.async {
                self.services = services
            }
        }
    }

    static let url = ShareMenuContentViewModel(preview: [URL(fileURLWithPath: "/")])
}
#endif

@available(iOS 13.0, *)
struct ShareButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "square.and.arrow.up")
        }
    }
}
#endif

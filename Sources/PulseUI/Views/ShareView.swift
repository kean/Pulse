// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS)
import UIKit

struct ShareView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]?
    private let cleanup: () -> Void
    private var completion: (() -> Void)?

    init(activityItems: [Any]) {
        self.activityItems = activityItems
        self.cleanup = {}
    }

    init(_ items: ShareItems) {
        self.activityItems = items.items
        self.cleanup = items.cleanup
    }

    func onCompletion(_ completion: @escaping () -> Void) -> Self {
        var copy = self
        copy.completion = completion
        return copy
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<ShareView>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        controller.completionWithItemsHandler = { _, _, _, _ in
            cleanup()
            completion?()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ShareView>) {
    }
}
#endif

#if os(macOS)
import AppKit
import Pulse

struct ShareView: View {
    let items: ShareItems

    private var cleanup: (() -> Void)?
    private var completion: (() -> Void)?

    init(_ items: ShareItems) {
        self.items = items
        self.cleanup = items.cleanup
    }

    func onCompletion(_ completion: @escaping () -> Void) -> Self {
        var copy = self
        copy.completion = completion
        return copy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let services = NSSharingService.sharingServices(forItems: items.items)
            ForEach(services, id: \.title) { service in
                Item(item: service) {
                    service.perform(withItems: items.items)
                }
            }
        }.padding(4)
    }

    private struct Item: View {
        let item: NSSharingService
        let action: () -> Void
        @State private var isHighlighted = false

        var body: some View {
            Button(action: action) {
                HStack {
                    Image(nsImage: item.image)
                    Text(item.title)
                    Spacer()
                }.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(4)
            .onHover { isHighlighted = $0 }
            .background {
                if isHighlighted {
                    Color.separator.cornerRadius(4)
                }
            }
        }
    }
}

#endif

#if os(macOS)
struct ShareNetworkTaskView: View {
    @ObservedObject var task: NetworkTaskEntity

    @AppStorage("com-github-kean-selected-task-sharing-option") private var output: Output = .plainText

    @State private var items: ShareItems?
    @Environment(\.store) private var store

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                NetworkRequestStatusCell(viewModel: .init(task: task, store: store))
                HStack {
                    VStack(alignment: .leading) {
                        Text(task.httpMethod ?? "GET").fontWeight(.semibold)
                        Text(task.url ?? "–")
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
            }
            .padding(8)
            Picker("", selection: $output) {
                ForEach(Output.allCases, id: \.self) {
                    Text($0.rawValue).tag($0.rawValue)
                }
            }
            .labelsHidden()
            .padding(8)
            Divider()
            if let items = items {
                ShareView(items)
            }
        }
        .onChange(of: output, perform: render)
        .onAppear { render(with: output) }
        .frame(width: 240)
    }

    private func render(with output: Output) {
        var asString: NSAttributedString {
            TextRenderer(options: .sharing).make {
                $0.render(task, content: .sharing, store: store)
            }
        }
        switch output {
        case .plainText:
            items = ShareService.share(asString, as: .plainText)
        case .html:
            items = ShareService.share(asString, as: .html)
        case .curl:
            items = ShareItems([task.cURLDescription()])
        }
    }

    enum Output: String, CaseIterable {
        case plainText = "Plain Text"
        case html = "HTML"
        case curl = "cURL"
    }
}

#if DEBUG
struct Previews_ShareView_Previews: PreviewProvider {
    static var previews: some View {
        ShareNetworkTaskView(task: LoggerStore.demo.entity(for: .login))
            .frame(height: 400)
    }
}
#endif

#endif

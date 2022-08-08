// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct KeyValueSectionView: View {
    let viewModel: KeyValueSectionViewModel
    var limit: Int = Int.max
    private var hideTitle = false

    init(viewModel: KeyValueSectionViewModel) {
        self.viewModel = viewModel
    }

    init(viewModel: KeyValueSectionViewModel, limit: Int) {
        self.viewModel = viewModel
        self.limit = limit
    }

    func hiddenTitle() -> KeyValueSectionView {
        var copy = self
        copy.hideTitle = true
        return copy
    }

    private var actualTintColor: Color {
        viewModel.items.isEmpty ? .gray : viewModel.color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !hideTitle {
                headerView
            }
#if os(watchOS)
            KeyValueListView(viewModel: viewModel, limit: limit)
                .padding(.top, 6)
                .border(width: 2, edges: [.top], color: actualTintColor)
                .padding(.top, 2)

            if let action = viewModel.action, !viewModel.items.isEmpty {
                Spacer().frame(height: 8)
                Button(action: action.action, label: {
                    Text(action.title)
                    Image(systemName: "chevron.right")
                        .foregroundColor(.separator)
                        .font(.caption)
                })

            }
#else
            KeyValueListView(viewModel: viewModel, limit: limit)
                .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 0))
                .border(width: 2, edges: [.leading], color: actualTintColor)
                .padding(EdgeInsets(top: 0, leading: 1, bottom: 0, trailing: 0))
#endif
        }
    }

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Text(viewModel.title)
                .font(.headline)
            Spacer()
#if os(iOS)
            if let action = viewModel.action, !viewModel.items.isEmpty {
                makeActionButton(with: action)
            }
#endif
        }
    }

    @ViewBuilder
    private func makeActionButton(with action: ActionViewModel) -> some View {
        Button(action: action.action) {
            HStack(spacing: 4) {
                Text(action.title)
                    .font(.body)
                    .foregroundColor(.accentColor)
                Image(systemName: "chevron.right")
                    .foregroundColor(Color.gray)
                    .font(.caption)
                    .padding(.top, 2)
            }.padding(.trailing, -6)
        }
    }
}

private struct KeyValueListView: View {
    let viewModel: KeyValueSectionViewModel
    var limit: Int = Int.max

    private var actualTintColor: Color {
        viewModel.items.isEmpty ? .gray : viewModel.color
    }

    var items: [(String, String?)] {
        var items = Array(viewModel.items.prefix(limit))
        if viewModel.items.count > limit {
            items.append(("And \(viewModel.items.count - limit) more", "..."))
        }
        return items
    }

#if os(macOS)
    var body: some View {
        if viewModel.items.isEmpty {
            HStack {
                Text("Empty")
                    .foregroundColor(actualTintColor)
                    .font(.system(size: fontSize, weight: .medium))
            }
        } else {
            Label(text: text)
                .padding(.bottom, 5)
        }
    }

    private var text: NSAttributedString {
        let text = NSMutableAttributedString()
        for (index, row) in items.enumerated() {
            text.append(makeRow(row))
            if index != items.indices.last {
                text.append("\n")
            }
        }
        return text
    }

    private func makeRow(_ row: (String, String?)) -> NSAttributedString {
        let text = NSMutableAttributedString()
        text.append(row.0 + ": ", [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: NSColor(actualTintColor),
            .paragraphStyle: ps
        ])
        text.append(row.1 ?? "–", [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor(Color.primary),
            .paragraphStyle: ps
        ])
        return text
    }
#else
    var body: some View {
        if viewModel.items.isEmpty {
            HStack {
                Text("Empty")
                    .foregroundColor(actualTintColor)
                    .font(.system(size: fontSize, weight: .medium))
            }
        } else {
            VStack(spacing: 2) {
                let rows = items.enumerated().map(KeyValueRow.init)
                ForEach(rows, content: makeRow)
            }
        }
    }

    private func makeRow(_ row: KeyValueRow) -> some View {
        HStack {
            let title = Text(row.item.0 + ": ")
                .foregroundColor(actualTintColor)
                .font(.system(size: fontSize, weight: .medium))
            let value = Text(row.item.1 ?? "–")
                .foregroundColor(.primary)
                .font(.system(size: fontSize, weight: .regular))
            (title + value)
                .lineLimit(row.item.0 == "URL" ? 3 : 3)
#if os(iOS)
                .backport.contextMenu(menuItems: {
                    makeContextMenu(for: row.item)
                }, preview: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(row.item.0)
                            .foregroundColor(actualTintColor)
                            .font(.system(size: fontSize, weight: .medium))
                        Text(row.item.1 ?? "–")
                            .foregroundColor(.primary)
                            .font(.system(size: fontSize, weight: .regular))
                            .lineLimit(24)
                    }
                    .padding()
                    .frame(width: 340)
                })
#endif
            Spacer()
        }
    }
#endif

#if os(iOS)
    @ViewBuilder
    func makeContextMenu(for item: (String, String?)) -> some View {
        makeCopyButton(title: "Copy Pair", value: "\(item.0): \(item.1 ?? "–")")
        makeCopyButton(title: "Copy Key", value: item.0)
        makeCopyButton(title: "Copy Value", value: item.1)
    }

    func makeCopyButton(title: String, value: String?) -> some View {
        Button(action: {
            UXPasteboard.general.string = value
            runHapticFeedback()
        }) {
            Text(title)
            Image(systemName: "doc.on.doc")
        }
    }
#endif
}

#if os(macOS)
private struct Label: NSViewRepresentable {
    let text: NSAttributedString

    func makeNSView(context: Context) -> NSTextField {
        let label = NSTextField.label()
        label.isSelectable = true
        label.allowsEditingTextAttributes = true
        label.lineBreakMode = .byCharWrapping
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.attributedStringValue = text
    }
}

private let ps: NSParagraphStyle = {
    let ps = NSMutableParagraphStyle()
    ps.minimumLineHeight = 20
    ps.maximumLineHeight = 20
    return ps
}()
#endif

private var fontSize: CGFloat {
#if os(iOS)
    return 15
#elseif os(watchOS)
    return 14
#elseif os(tvOS)
    return 28
#else
    return 12
#endif
}

struct KeyValueSectionViewModel {
    let title: String
    let color: Color
    var action: ActionViewModel?
    var items: [(String, String?)] = []
}

struct KeyValueRow: Identifiable {
    let id: Int
    let item: (String, String?)

    var title: String { item.0 }
    var details: String? { item.1 }
}

struct ActionViewModel {
    let action: () -> Void
    let title: String
}

#if DEBUG
struct KeyValueSectionView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {

            KeyValueSectionView(viewModel: .init(
                title: "Summary",
                color: .red,
                items: [("URL", "https://github.com/kean/Pulse/blob/master/Sources/PulseUI/Features/Console/This/Is/A/Very/Long/URL/that-does-not-fit-in-the-review/But/with?ios=16.0,feature=ContextMenuPreview,backport=yes,easy-to-preview-the-whole-thing-now=yes")])
            )
            KeyValueSectionView(viewModel: .init(
                title: "Headers",
                color: .blue,
                action: .init(action: {}, title: "Show Raw"),
                items: [
                    ("Content-Length", "21851748"),
                    ("Content-Type", "multipart/form-data; boundary=----WebKitFormBoundaryrv8XAHQPtQcWta3k"),
                    ("User-Agent", "Pulse%20Demo%20iOS/20 CFNetwork/1385 Darwin/22.0.0")
                ])
            )
        }
        .padding()
        .frame(width: 400)
        .previewLayout(.sizeThatFits)
    }
}
#endif

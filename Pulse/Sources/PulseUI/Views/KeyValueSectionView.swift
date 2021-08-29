// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI

@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
struct KeyValueSectionView: View {
    let model: KeyValueSectionViewModel
    var limit: Int = Int.max

    private var actualTintColor: Color {
        model.items.isEmpty ? .gray : model.color
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(model.title)
                    .font(.headline)
                Spacer()
                #if os(iOS)
                if let action = model.action {
                    Button(action: action.action, label: {
                        Text(action.title)
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color.gray)
                            .font(.caption)
                            .padding(.top, 2)
                    })
                    .padding(EdgeInsets(top: 7, leading: 11, bottom: 7, trailing: 11))
                    .background(Color.secondaryFill)
                    .cornerRadius(20)
                }
                #endif
            }
            #if os(watchOS)
            KeyValueListView(model: model, limit: limit)
                .padding(.top, 6)
                .border(width: 2, edges: [.top], color: actualTintColor)
                .padding(.top, 2)

            if let action = model.action {
                Spacer().frame(height: 10)
                Button(action: action.action, label: {
                    Text(action.title)
                    Image(systemName: "chevron.right")
                        .foregroundColor(.separator)
                        .font(.caption)
                })
 
            }

            #else
            KeyValueListView(model: model, limit: limit)
                .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 0))
                .border(width: 2, edges: [.leading], color: actualTintColor)
                .padding(EdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 0))
            Spacer()
            #endif
        }
    }
}

@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
private struct KeyValueListView: View {
    let model: KeyValueSectionViewModel
    var limit: Int = Int.max

    private var actualTintColor: Color {
        model.items.isEmpty ? .gray : model.color
    }

    var items: [(String, String?)] {
        var items = Array(model.items.prefix(limit))
        if model.items.count > limit {
            items.append(("And \(model.items.count - limit) more", "..."))
        }
        return items
    }

    var body: some View {
        if model.items.isEmpty {
            HStack {
            Text("Empty")
                .foregroundColor(actualTintColor)
                .font(.system(size: fontSize, weight: .medium))
            }
        } else {
            VStack(spacing: 2) {

                let rows = items.enumerated().map(Row.init)
                ForEach(rows, id: \.index, content: makeRow)
            }
        }
    }

    private func makeRow(_ row: Row) -> some View {
        HStack {
            let title = Text(row.item.0 + ": ")
                .foregroundColor(actualTintColor)
                .font(.system(size: fontSize, weight: .medium))
            let value = Text(row.item.1 ?? "–")
                .foregroundColor(.primary)
                .font(.system(size: fontSize, weight: .regular))
            #if os(watchOS)
            VStack(alignment: .leading) {
                title
                value
                    .lineLimit(2)
            }
            #elseif os(tvOS)
            (title + value)
                .lineLimit(nil)
            #else
            (title + value)
                .lineLimit(nil)
                .contextMenu(ContextMenu(menuItems: {
                    Button(action: {
                        UXPasteboard.general.string = "\(row.item.0): \(row.item.1 ?? "–")"
                        runHapticFeedback()
                    }) {
                        Text("Copy")
                        Image(systemName: "doc.on.doc")
                    }
                    Button(action: {
                        UXPasteboard.general.string = row.item.1
                        runHapticFeedback()
                    }) {
                        Text("Copy Value")
                        Image(systemName: "doc.on.doc")
                    }
                }))
            #endif
            Spacer()
        }
    }
}

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

@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
struct KeyValueSectionViewModel {
    let title: String
    let color: Color
    var action: ActionViewModel?
    let items: [(String, String?)]
}

private struct Row {
    let index: Int
    let item: (String, String?)
}

struct ActionViewModel {
    let action: () -> Void
    let title: String
}

// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS) || os(macOS)

struct PickerItem<Tag: Hashable> {
    let title: String
    let tag: Tag
}

@available(iOS 13.0, *)
struct MultiSelectionPicker<Tag: Hashable>: View {
    let title: String
    let items: [PickerItem<Tag>]
    var emptyLabel = "None"
    @Binding var selected: Set<Tag>

    @State private var isPickerPresented = false

    #if os(iOS)
    var body: some View {
        NavigationLink(destination: MultiSelectionPickerListView(title: title, items: items, selected: $selected)) {
            Text(title)
            Spacer()
            Text(makeEmptyLabel())
                .foregroundColor(Color.secondary)
        }
    }
    #else
    var body: some View {
        HStack {
            Text(title)
            Button(action: {
                isPickerPresented.toggle()
            }){
                Text(makeEmptyLabel())
            }
        }
        .sheet(isPresented: $isPickerPresented) {
            MultiSelectionPickerListView(title: title, items: items, selected: $selected)
                .toolbar {
                    Button(action: { isPickerPresented = false }) {
                        Text("Done")
                    }.keyboardShortcut(.defaultAction)
                }
        }
    }
    #endif

    private func makeEmptyLabel() -> String {
        switch selected.count {
        case 0: return emptyLabel
        case 1: return items.first(where: { $0.tag == selected.first! })!.title
        case items.count: return "All"
        default: return "Multiple (\(selected.count))"
        }
    }
}

@available(iOS 13.0, *)
struct MultiSelectionPickerListView<Tag: Hashable>: View {
    let title: String
    let items: [PickerItem<Tag>]
    @Binding var selected: Set<Tag>
    @State private var isReloadNeeded = false // workaround

    var body: some View {
        #if os(iOS)
        Form {
            Section(header: controls) {
                listContent
            }
        }
        .navigationBarTitle(title)
        #else
        VStack {
            Form {
                Section(header: Text(title), footer: controls.padding(.top, 20)) {
                    listContent
                }
            }
        }
        .padding()
        #endif
    }

    private var listContent: some View {
        ForEach(items, id: \.tag) { item in
            #if os(iOS)
            HStack {
                Text(item.title)
                    .foregroundColor(.primary)
                Spacer()
                if selected.contains(item.tag) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                toggleSelection(for: item.tag)
            }
            #else
            Toggle(item.title, isOn: Binding(get: {
                selected.contains(item.tag)
            }, set: { isOn in
                if isOn {
                    selected.insert(item.tag)
                } else {
                    selected.remove(item.tag)
                }
            }))
            #endif
        }
    }

    private var controls: some View {
        HStack {
            Button("Select All") {
                selected = Set(items.map { $0.tag })
                isReloadNeeded = true
            }
            Spacer()
                .frame(width: 12)
            Button("Deselect All") {
                selected.removeAll()
                isReloadNeeded = true
            }
        }
    }

    private func toggleSelection(for tag: Tag) {
        if selected.contains(tag) {
            selected.remove(tag)
        } else {
            selected.insert(tag)
        }
        isReloadNeeded = true
    }
}

@available(iOS 13.0, *)
struct MultiSelectionPickerListView_Previews: PreviewProvider {
    @State static var selected = Set([0, 2])

    static var previews: some View {
        NavigationView {
            MultiSelectionPickerListView(
                title: "Log Level",
                items: [
                    .init(title: "Trace", tag: 0),
                    .init(title: "Debug", tag: 1),
                    .init(title: "Info", tag: 2)
                ],
                selected: $selected
            )
        }
    }
}

#endif

// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import SwiftUI
import Pulse

struct SettingsConsoleCellDesignView: View {
    @EnvironmentObject private var settings: UserSettings

    var body: some View {
        VStack(spacing: 0) {
            preview

            Form {
                SettingsConsoleTaskOptionsView(options: $settings.displayOptions)
            }
            .environment(\.editMode, .constant(.active))
        }
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("Reset") {
                    settings.displayOptions = .init()
                }
            }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Preview".uppercased())
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
                .padding(.bottom, 8)

            if let previewTask = StorePreview.previewTask {
                Divider()
                ConsoleTaskCell(task: previewTask, isDisclosureNeeded: true)
                    .padding()
                    .background(Color(.systemBackground))
                Divider()
            } else {
                Text("Failed to load the preview")
            }
        }
        .padding(.top, 16)
        .background(Color(.secondarySystemBackground))
    }
}

private struct SettingsConsoleTaskOptionsView: View {
    @Binding var options: DisplayOptions

    @State private var isShowingFieldPicker = false

    var body: some View {
        Section("Content") {
            content
        }
        Section("Details") {
            details
        }
    }

    typealias FontSize = DisplayOptions.FontSize

    @ViewBuilder
    private var content: some View {
        Stepper("Font Size: \(options.contentFontSize)", value: $options.contentFontSize, in: (defaultContentFontSize-3)...(defaultContentFontSize+3))

        Stepper("Line Limit: \(options.contentLineLimit)", value: $options.contentLineLimit, in: 1...20)

        Toggle("Show Task Description", isOn: $options.showTaskDescription)

        NavigationLink {
            // TODO: navigation link
            List(selection: $options.contentComponents) {
                ForEach(UserSettings.DisplayOptions.ContentComponent.allCases) {
                    Text($0.rawValue).tag($0.rawValue)
                }
            }
            .navigationTitle("Components")
            .navigationBarTitleDisplayMode(.inline)
        } label: {
            HStack {
                Text("URL Components")
                Spacer()
                if options.contentComponents.count == 1 {
                    Text(options.contentComponents.first!.rawValue)
                        .foregroundStyle(.secondary)
                } else {
                    Text(options.contentComponents.count.description)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var details: some View {
        Toggle("Show Details", isOn: $options.isShowingDetails)

        if options.isShowingDetails {
            Stepper("Font Size: \(options.detailsFontSize)", value: $options.detailsFontSize, in: (defaultDefailsFontSize-3)...(defaultDefailsFontSize+3))

            Stepper("Line Limit: \(options.detailsLineLimit)", value: $options.detailsLineLimit, in: 1...20)

            ForEach(options.detailsFields) { field in
                Text(field.title)
            }
            .onMove { from, to in
                options.detailsFields.move(fromOffsets: from, toOffset: to)
            }
            .onDelete { indexSet in
                options.detailsFields.remove(atOffsets: indexSet)
            }
            Button {
                isShowingFieldPicker = true
            } label: {
                Label("Add Field", systemImage: "plus.circle")
                    .offset(x: -2, y: 0)
            }
            .sheet(isPresented: $isShowingFieldPicker) {
                NavigationView {
                    ConsoleFieldPicker(currentSelection: Set(options.detailsFields)) {
                        options.detailsFields.append($0)
                    }
                }
            }
        }
    }
}
              

private struct ConsoleFieldPicker: View {
    @State var selection: DisplayOptions.Field?
    let currentSelection: Set<DisplayOptions.Field>
    let onSelection: (DisplayOptions.Field) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Picker("Field", selection: $selection) {
                let remainingCases = DisplayOptions.Field.allCases.filter {
                    !currentSelection.contains($0)
                }
                ForEach(remainingCases) { field in
                    Text(field.title)
                        .tag(Optional.some(field))
                }
            }
            .pickerStyle(.inline)
        }
        .onChange(of: selection) { value in
            if let value {
                dismiss()
                onSelection(value)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .navigationTitle("Add Field")
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum StorePreview {
    static let store = try? LoggerStore(storeURL: URL(fileURLWithPath: "/dev/null"), options: [.synchronous, .inMemory])

    static let previewTask: NetworkTaskEntity? = {
        guard let store else { return nil }

        let url = URL(string: "https://user:password@api.example.com:443/v2.1/sites/91023547/users/49032328/profile?locale=en&fields=id,firstName,lastName,email,avatarURL#me")!

        var request = URLRequest(url: url)
        request.setValue("Pulse", forHTTPHeaderField: "User-Agent")
        request.setValue("Accept", forHTTPHeaderField: "application/json")

        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "http/2.0", headerFields: [
            "Content-Length": "412",
            "Content-Type": "application/json; charset=utf-8",
            "Cache-Control": "no-store",
            "Content-Encoding": "gzip"
        ])

        // TODO: add taskDescription support
        store.storeRequest(request, response: response, error: nil, data: Data(count: 412), taskDescription: nil)

        let task = try? store.tasks().first
        // It's a bit hard to pass this info
        task?.duration = 150
        return task
    }()
}

#if DEBUG
#Preview {
    NavigationView {
        SettingsConsoleCellDesignView()
            .injecting(ConsoleEnvironment(store: StorePreview.store!))
            .environmentObject(UserSettings.shared)
            .navigationTitle("Cell Design")
            .navigationBarTitleDisplayMode(.inline)
    }
}
#endif

#endif

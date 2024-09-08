// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import SwiftUI
import Pulse

struct SettingsConsoleCellDesignView: View {
    @EnvironmentObject private var settings: UserSettings

    @FetchRequest(sortDescriptors: [SortDescriptor(\.createdAt, order: .forward)])
    var tasks: FetchedResults<NetworkTaskEntity>

    var body: some View {
        VStack(spacing: 0) {
            preview
            Form {
                Section("Options") {
                    Stepper("Line Limit: \(settings.lineLimit)", value: $settings.lineLimit, in: 1...20)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("Reset") {
                    // TODO: implement
                }
            }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Preview".uppercased())
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 8)

            if let previewTask = StorePreview.previewTask {
                Divider()
                    .padding(.leading)
                ConsoleTaskCell(task: previewTask, isDisclosureNeeded: true)
                    .padding()
                Divider()
            } else {
                Text("Failed to load the preview")
            }
        }
        .background(Color(.systemBackground))
    }
}

enum StorePreview {
    static let store = try? LoggerStore(storeURL: URL(fileURLWithPath: "/dev/null"), options: [.synchronous, .inMemory])

    static let previewTask: NetworkTaskEntity? = {
        guard let store else { return nil }

        let url = URL(string: "https://api.example.com/v2.1/sites/91023547/users/49032328/profile?locale=en&fields=id,firstName,lastName,email,avatarURL")!

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

        return try? store.tasks().first
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

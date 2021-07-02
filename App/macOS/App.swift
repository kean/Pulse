// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import Cocoa
import PulseCore
import PulseUI
import SwiftUI
import Combine

// MARK: - PulseApp

@main
struct PulseApp: App {
    var body: some Scene {
        WindowGroup {
            WelcomeView()
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            AppCommands()
        }

        WindowGroup {
            AppView()
        }
        .handlesExternalEvents(matching: ["file"])
        .windowToolbarStyle(UnifiedWindowToolbarStyle(showsTitle: false))
        .commands {
            SidebarCommands()
            ToolbarCommands()
        }

        WindowGroup {
            DetailsView()
        }
        .handlesExternalEvents(matching: ["com-github-kean-pulse"])
        .windowToolbarStyle(UnifiedWindowToolbarStyle(showsTitle: false))
    }
}

struct DetailsView: View {
    var body: some View {
        ExternalEvents.open
    }
}

struct AppView: View {
    @StateObject var model = AppViewModel()

    var body: some View {
        contents
            .onOpenURL(perform: model.openDatabase)
    }

    @ViewBuilder
    private var contents: some View {
        if let store = model.selectedStore {
            MainView(store: store)
        } else if let alert = model.alert {
            PlaceholderView(imageName: "exclamationmark.circle.fill", title: alert.title, subtitle: alert.message)
        } else {
            PlaceholderView(imageName: "exclamationmark.circle.fill", title: "Failed to open store", subtitle: nil)
        }
    }
}

struct WelcomeView: View {
    @State private var window: NSWindow?
    @StateObject var model = AppViewModel()

    var body: some View {
        contents
            .background(WindowAccessor(window: $window))
            .onReceive(NotificationCenter.default.publisher(for: .hideWelcomeWindow), perform: { _ in
                window?.close()
            })
            .alert(item: $model.alert) {
                Alert(title: Text($0.title), message: Text($0.message), dismissButton: .cancel(Text("Ok")))
            }
    }

    @ViewBuilder
    private var contents: some View {
        AppWelcomeView(buttonOpenDocumentTapped: openDocument)
            .ignoresSafeArea()
            .frame(width: 800, height: 460)
    }
}

func openDocument() {
    let dialog = NSOpenPanel()

    dialog.title = "Select a Pulse document (has .pulse extension)"
    dialog.showsResizeIndicator = true
    dialog.showsHiddenFiles = false
    dialog.canChooseDirectories = false
    dialog.canCreateDirectories = false
    dialog.allowsMultipleSelection = false
    dialog.canChooseDirectories = true
    dialog.allowedFileTypes = ["pulse"]

    guard dialog.runModal() == NSApplication.ModalResponse.OK else {
        return // User cancelled the action
    }

    if let selectedUrl = dialog.url {
        NSWorkspace.shared.open(selectedUrl)
    }
}

// MARK: - AppViewModel

final class AppViewModel: ObservableObject {
    @Published var selectedStore: LoggerStore?
    @Published var alert: AlertViewModel?

    init() {
//        if ProcessInfo.processInfo.environment["PULSE_MOCK_STORE_ENABLED"] != nil {
            // selectedStore = .mock
//        }
    }

    func openDatabase(at url: URL) {
        do {
            self.selectedStore = try LoggerStore(storeURL: url)
            NotificationCenter.default.post(name: .hideWelcomeWindow, object: nil)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch {
            alert = AlertViewModel(title: "Failed to open Pulse document", message: error.localizedDescription)
        }
    }
}

private extension NSNotification.Name {
    static let hideWelcomeWindow = NSNotification.Name(rawValue: "hide-welcome-window")
}

struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.window = view.window
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct AlertViewModel: Hashable, Identifiable {
    var id: String = UUID().uuidString
    let title: String
    let message: String
}

enum AppViewModelError: Error, LocalizedError {
    case failedToFindLogsStore(url: URL)

    var errorDescription: String? {
        switch self {
        case .failedToFindLogsStore(let url):
            return "Failed to find a Pulse store at the given URL \(url)"
        }
    }
}

struct PlaceholderView: View {
    var imageName: String?
    let title: String
    var subtitle: String?

    var body: some View {
        VStack {
            imageName.map(Image.init(systemName:))
                .font(.system(size: 100, weight: .light))
            Spacer().frame(height: 32)
            Text(title)
                .font(.title)
                .multilineTextAlignment(.center)
            if let subtitle = self.subtitle {
                Spacer().frame(height: 10)
                Text(subtitle)
                    .multilineTextAlignment(.center)
            }
        }
        .foregroundColor(.secondary)
        .frame(minWidth: 800, maxHeight: 600)
    }
}

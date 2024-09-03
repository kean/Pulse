// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS)

import SwiftUI
import CoreData
import Pulse
import Combine

@available(iOS 15, visionOS 1.0, *)
struct ConsoleContextMenu: View {
    @EnvironmentObject private var environment: ConsoleEnvironment
    @Environment(\.router) private var router

    var body: some View {
        Menu {
            Section {
                Button(action: { router.isShowingSessions = true }) {
                    Label("Sessions", systemImage: "list.bullet.clipboard")
                }
            }
            Section {
                ConsoleSortByMenu()
            }
            Section {
                Button(action: { router.isShowingSettings = true }) {
                    Label("Settings", systemImage: "gear")
                }
                if !environment.store.options.contains(.readonly) {
                    Button(role: .destructive, action: environment.removeAllLogs) {
                        Label("Remove Logs", systemImage: "trash")
                    }
                }
            }
            Section {
                if !UserDefaults.standard.bool(forKey: "pulse-disable-support-prompts") {
                    Button(action: buttonGetPulseProTapped) {
                        Label("Get Pulse Pro", systemImage: "link")
                    }
                }
                Button(action: buttonSendFeedbackTapped) {
                    Label("Report Issue", systemImage: "envelope")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private func buttonGetPulseProTapped() {
        URL(string: "https://pulselogger.com").map(openURL)
    }

    private func buttonSendFeedbackTapped() {
        URL(string: "https://github.com/kean/Pulse/issues").map(openURL)
    }

    private func openURL(_ url: URL) {
        UIApplication.shared.open(url)
    }
}

private struct ConsoleSortByMenu: View {
    @EnvironmentObject private var environment: ConsoleEnvironment

    var body: some View {
        Menu(content: {
            if environment.mode == .network {
                Picker("Sort By", selection: $environment.listOptions.taskSortBy) {
                    ForEach(ConsoleListOptions.TaskSortBy.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
            } else {
                Picker("Sort By", selection: $environment.listOptions.messageSortBy) {
                    ForEach(ConsoleListOptions.MessageSortBy.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
            }
            Picker("Ordering", selection: $environment.listOptions.order) {
                Text("Descending").tag(ConsoleListOptions.Ordering.descending)
                Text("Ascending").tag(ConsoleListOptions.Ordering.ascending)
            }
        }, label: {
            Label("Sort By", systemImage: "arrow.up.arrow.down")
        })
    }
}
#endif

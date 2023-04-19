// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import CoreData
import Pulse
import Combine

struct ShareStoreView: View {
    /// Preselected sessions.
    var sessions: Set<UUID> = []
    var onDismiss: () -> Void

    @State private var isShowingLabelPicker = false
    @StateObject private var viewModel = ShareStoreViewModel()

    @Environment(\.store) private var store: LoggerStore

    var body: some View {
        content
            .onAppear {
                if !sessions.isEmpty {
                    viewModel.sessions = sessions
                } else if viewModel.sessions.isEmpty {
                    viewModel.sessions = [store.session.id]
                }
                viewModel.store = store
            }
    }

    @ViewBuilder
    private var content: some View {
#if os(iOS)
        Form {
            sectionSharingOptions
            sectionShare
        }
        .inlineNavigationTitle("Share Logs")
        .navigationBarItems(leading: Button("Cancel", action: onDismiss))
        .sheet(item: $viewModel.shareItems) {
            ShareView($0).onCompletion(onDismiss)
        }
#elseif os(macOS)
        Form {
            sectionSharingOptions
            Divider()
            sectionShare.popover(item: $viewModel.shareItems, arrowEdge: .trailing) {
                ShareView($0)
            }
        }
        .listStyle(.sidebar)
        .padding()
        .popover(isPresented: $isShowingLabelPicker, arrowEdge: .trailing) {
            destinationLogLevels.padding()
        }
#endif
    }

    @ViewBuilder
    private var sectionSharingOptions: some View {
        Section {
            ConsoleSessionsPickerView(selection: $viewModel.sessions)
#if os(iOS)
            NavigationLink(destination: destinationLogLevels) {
                InfoRow(title: "Log Levels", details: viewModel.selectedLevelsTitle)
            }
#else
            HStack {
                Text("Log Levels")
                Spacer()
                Button(action: { isShowingLabelPicker = true }) {
                    Text(viewModel.selectedLevelsTitle + "...")
                }
            }
#endif
        }
        Section {
            Picker("Output", selection: $viewModel.output) {
                Text("Pulse").tag(ShareStoreOutput.store)
                Text("Plain Text").tag(ShareStoreOutput.text)
                Text("HTML").tag(ShareStoreOutput.html)
                Divider()
                Text("Pulse (Package)").tag(ShareStoreOutput.package)
            }
#if os(macOS)
            .labelsHidden()
#endif
        }
    }

    private var destinationLogLevels: some View {
        Form {
            ConsoleSearchLogLevelsCell(selection: $viewModel.logLevels)
        }.inlineNavigationTitle("Log Levels")
    }

    private var sectionShare: some View {
        Section {
            Button(action: { viewModel.buttonSharedTapped() }) {
#if os(iOS)
                HStack {
                    Spacer()
                    Text(viewModel.isPreparingForSharing ? "Exporting..." : "Share")
                        .bold()
                    Spacer()
                }
#else
                Text(viewModel.isPreparingForSharing ? "Exporting..." : "Share")
#endif
            }
            .disabled(viewModel.isPreparingForSharing)
            .foregroundColor(.white)
#if os(iOS)
            .listRowBackground(viewModel.isPreparingForSharing ? Color.blue.opacity(0.33) : Color.blue)
#endif
        }
    }
}

#if DEBUG
struct ShareStoreView_Previews: PreviewProvider {
    static var previews: some View {
#if os(iOS)
        NavigationView {
            ShareStoreView(onDismiss: {})
        }
        .injecting(.init(store: .mock))
#else
        ShareStoreView(onDismiss: {})
            .injecting(.init(store: .mock))
            .frame(width: 240).fixedSize()
#endif
    }
}
#endif

#endif

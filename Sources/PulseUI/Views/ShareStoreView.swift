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

    @StateObject private var viewModel = ShareStoreViewModel()

    @Environment(\.store) private var store: LoggerStore

#if os(macOS)
    let onShare: (ShareItems) -> Void
#endif

    var body: some View {
        Form {
            sectionSharingOptions
            sectionShare
        }
        .onAppear {
            if !sessions.isEmpty {
                viewModel.sessions = sessions
            } else if viewModel.sessions.isEmpty {
                viewModel.sessions = [store.session.id]
            }
            viewModel.store = store
        }
        .navigationTitle("Share Logs")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(leading: Button("Cancel", action: onDismiss))
#endif
        .sheet(item: $viewModel.shareItems) {
            ShareView($0).onCompletion(onDismiss)
        }
#if os(macOS)
        .onChange(of: viewModel.shareItems) {
            onShare($0)
        }
        .padding()
#endif
    }

    @ViewBuilder
    private var sectionSharingOptions: some View {
        Section {
            NavigationLink(destination: SessionPickerView(selection: $viewModel.sessions)) {
                InfoRow(title: "Sessions", details: viewModel.selectedSessionTitle)
            }
            NavigationLink(destination: destinationLogLevels) {
                InfoRow(title: "Log Levels", details: viewModel.selectedLevelsTitle)
            }
        }
        Section {
            Picker("Output Format", selection: $viewModel.output) {
                Text("Pulse").tag(ShareStoreOutput.store)
                Text("Plain Text").tag(ShareStoreOutput.text)
                Text("HTML").tag(ShareStoreOutput.html)
            }
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
                HStack {
                    Spacer()
                    Text(viewModel.isPreparingForSharing ? "Exporting..." : "Share").bold()
                    Spacer()
                }
            }
            .disabled(viewModel.isPreparingForSharing)
            .foregroundColor(.white)
            .listRowBackground(viewModel.isPreparingForSharing ? Color.blue.opacity(0.33) : Color.blue)
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
        .injectingEnvironment(.init(store: .mock))
#else
        ShareStoreView(isPresented: .constant(true), onShare: { _ in })
            .environment(\.store, .demo)
            .frame(width: 300, height: 500)
#endif
    }
}
#endif

#endif

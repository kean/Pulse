// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(watchOS)

import SwiftUI
import CoreData
import Pulse
import Combine

@available(iOS 15, macOS 13, watchOS 9, *)
struct ShareStoreView: View {
    /// Preselected sessions.
    var sessions: Set<UUID> = []
    var onDismiss: () -> Void

    @State private var isShowingLabelPicker = false
    @State private var isShowingPreparingForShareView = false
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
#if os(iOS) || os(watchOS)
        Form {
            sectionSharingOptions
            sectionShare
        }
        .inlineNavigationTitle("Share Logs")
        .toolbar {
#if os(watchOS)
            ToolbarItem(placement: .cancellationAction) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                }
            }
#else
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel", action: onDismiss)
            }
#endif
        }
#if os(iOS) || os(macOS)
        .sheet(item: $viewModel.shareItems) {
            ShareView($0).onCompletion(onDismiss)
        }
#endif
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

#if os(iOS) || os(macOS)
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
#else
    private var sectionShare: some View {
        Section {
            NavigationLink(destination: VStack {
                if let shareItems = viewModel.shareItems {
                    ShareLink(items: shareItems.items as! [URL])
                } else {
                    ProgressView(label: {
                        Text("Exporting...")
                    }).onAppear {
                        viewModel.prepareForSharing()
                    }
                }
            }, label: {
                Text("Share...")
            })
        }
    }
#endif
}

#if DEBUG
@available(iOS 15, macOS 13, watchOS 9, *)
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

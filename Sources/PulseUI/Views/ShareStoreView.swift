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
    var sessions: Set<UUID>?

    @StateObject private var viewModel = ShareStoreViewModel()
    @Binding var isPresented: Bool // presentationMode is buggy

    @Environment(\.store) private var store: LoggerStore

    #warning("test this on macos")
#if os(macOS)
    let onShare: (ShareItems) -> Void
#endif

    var body: some View {
        Form {
            sectionSharingOptions
            sectionShare
        }
        .onAppear { viewModel.store = store }
        .navigationTitle("Share Store")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(leading: leadingBarItems)
#endif
        .sheet(item: $viewModel.shareItems) {
            ShareView($0).onCompletion {
                isPresented = false
            }
        }
#if os(macOS)
        .padding()
#endif
    }

    private var leadingBarItems: some View {
        Button("Cancel") {
            isPresented = false
        }
    }

    private var sectionSharingOptions: some View {
        Section {
            Picker("Time Range", selection: $viewModel.timeRange) {
                ForEach(SharingTimeRange.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            Picker("Minimum Log Level", selection: $viewModel.level) {
                Text("Trace").tag(LoggerStore.Level.trace)
                Text("Debug").tag(LoggerStore.Level.debug)
                Text("Error").tag(LoggerStore.Level.error)
            }
            Picker("Output Format", selection: $viewModel.output) {
                Text("Pulse File").tag(ShareStoreOutput.store)
                Text("Plain Text").tag(ShareStoreOutput.text)
                Text("HTML").tag(ShareStoreOutput.html)
            }
        }
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
            ShareStoreView(isPresented: .constant(true))
                .environment(\.store, .demo)
        }
#else
        ShareStoreView(isPresented: .constant(true), onShare: { _ in })
            .environment(\.store, .demo)
            .frame(width: 300, height: 500)
#endif
    }
}
#endif

#endif

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import CoreData
import Pulse
import Combine

struct ShareStoreView: View {
    let store: LoggerStore

    @StateObject private var viewModel = ShareStoreViewModel()
    @State private var shareItem: ShareItems?
    @Binding var isPresented: Bool // presentationMode is buggy

#if os(macOS)
    let onShare: (ShareItems) -> Void
#endif

    var body: some View {
        Form {
            sectionSharingOptions
            sectionStatus
            sectionShare
        }
        .onAppear { viewModel.display(store) }
        .navigationTitle("Sharing Options")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(leading: leadingBarItems)
#endif
        .sheet(item: $shareItem) {
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

    private var sectionStatus: some View {
        Section {
            if viewModel.isPreparingForSharing {
                HStack(spacing: 8) {
#if os(iOS)
                    ProgressView().id(UUID())
#endif
                    Text("Preparing for Sharing...")
                        .foregroundColor(.secondary)
                }
            } else if let contents = viewModel.sharedContents {
                if let info = contents.info {
#if os(iOS)
                    NavigationLink(destination: StoreDetailsView(source: .info(info))) {
                        InfoRow(title: "Shared File Size", details: contents.formattedFileSize)
                    }
#else
                    InfoRow(title: "Shared File Size", details: contents.formattedFileSize)
#endif
                } else {
                    InfoRow(title: "Shared File Size", details: contents.formattedFileSize)
                }
            } else {
                Text(viewModel.errorMessage ?? "Unavailable")
                    .foregroundColor(.red)
                    .lineLimit(3)
            }
        }
    }

    private var sectionShare: some View {
        Section {
            Button(action: buttonShareTapped) {
                HStack {
                    Spacer()
                    Text("Share").bold()
                    Spacer()
                }
            }
            .disabled(viewModel.sharedContents == nil)
            .foregroundColor(.white)
            .listRowBackground(viewModel.sharedContents != nil ? Color.blue : Color.blue.opacity(0.33))
        }
    }

    private func buttonShareTapped() {
        guard let item = viewModel.sharedContents?.item else { return }
#if os(macOS)
        onShare(item)
#else
        self.shareItem = item
#endif
    }
}

#if DEBUG
struct ShareStoreView_Previews: PreviewProvider {
    static var previews: some View {
#if os(iOS)
        NavigationView {
            ShareStoreView(store: .mock, isPresented: .constant(true))
        }
#else
        ShareStoreView(store: .mock, isPresented: .constant(true), onShare: { _ in })
            .frame(width: 300, height: 500)
#endif
    }
}
#endif

#endif

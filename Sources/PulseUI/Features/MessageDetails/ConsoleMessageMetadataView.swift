// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(iOS) || os(tvOS) || os(watchOS)
@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
struct ConsoleMessageMetadataView: View {
    let message: LoggerMessageEntity

    @State private var isMetadataRawLinkActive = false

    var body: some View {
        contents
            .background(linksView)
#if os(iOS)
            .navigationBarTitle("Details", displayMode: .inline)
#endif
    }

    @ViewBuilder
    private var contents: some View {
        ScrollView {
            VStack {
                KeyValueSectionView(viewModel: .init(title: "Summary", color: message.tintColor, items: [
                    ("Created At", dateFormatter.string(from: message.createdAt)),
                    ("Level", message.level),
                    ("Label", message.label.nonEmpty)
                ]))
                KeyValueSectionView(viewModel: .init(title: "Details", color: .secondary, items: [
                    ("Session", message.session.nonEmpty),
                    ("File", message.file.nonEmpty),
                    ("Filename", message.filename.nonEmpty),
                    ("Function", message.function.nonEmpty),
                    ("Line", message.line == 0 ? nil : "\(message.line)"),
                ]))
                KeyValueSectionView(viewModel: metadataViewModel)
            }.padding()
        }
    }

    private var metadataViewModel: KeyValueSectionViewModel {
        KeyValueSectionViewModel(title: "Metadata", color: .indigo, action: .init(action: {
            isMetadataRawLinkActive = true
        }, title: "View"), items: metadataItems)
    }

    private var metadataItems: [(String, String?)] {
        message.metadata.sorted(by: { $0.key < $1.key }).map { ($0.key, $0.value )}
    }

    private var linksView: some View {
        VStack {
            NavigationLink(destination: NetworkHeadersDetailsView(viewModel: metadataViewModel), isActive: $isMetadataRawLinkActive) {
                EmptyView()
            }
        }
    }
}

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
private extension LoggerMessageEntity {
    var tintColor: Color {
        Color.badgeColor(for: .init(rawValue: level) ?? .debug)
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS, yyyy-MM-dd"
    return formatter
}()

#if DEBUG
@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
struct ConsoleMessageMetadataView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                ConsoleMessageMetadataView(message: makeMockMessage())
            }
        }
    }
}
#endif

#endif

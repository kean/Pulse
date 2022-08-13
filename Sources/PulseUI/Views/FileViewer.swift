// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct FileViewer: View {
    @ObservedObject var viewModel: FileViewerViewModel
    @State var isWebViewOpen = false
    var onToggleExpanded: (() -> Void)?

#if os(iOS) || os(macOS)
    var body: some View {
        contents
            .onAppear { viewModel.render() }
            .sheet(isPresented: $isWebViewOpen) {
                NavigationView {
                    WebView(data: viewModel.data, contentType: "application/html")
#if os(iOS)
                        .navigationBarTitle("Browser Preview", displayMode: .inline)
                        .navigationBarItems(trailing: Button(action: {
                            isWebViewOpen = false
                        }) { Image(systemName: "xmark") })
#else
                        .navigationTitle("Browser Preview")
#endif
                }
            }
    }
#elseif os(watchOS)
    var body: some View {
        ScrollView {
            contents
        }.onAppear { viewModel.render() }
    }
#elseif os(tvOS)
    var body: some View {
        HStack {
            contents
            Spacer()
        }.onAppear { viewModel.render() }
    }
#endif

    @ViewBuilder
    private var contents: some View {
        if let contents = viewModel.contents {
            switch contents {
            case .json(let viewModel):
#if os(iOS)
                RichTextView(viewModel: viewModel, onToggleExpanded: onToggleExpanded) {
                    EmptyView()
                }
#else
                RichTextView(viewModel: viewModel)
#endif
            case .image(let viewModel):
                ScrollView {
                    ImageViewer(viewModel: viewModel)
                }
#if os(iOS) || os(macOS)
            case .pdf(let document):
                PDFKitRepresentedView(document: document)
#endif
            case .other(let viewModel):
#if os(iOS)
                RichTextView(viewModel: viewModel, onToggleExpanded: onToggleExpanded) {
                    if self.viewModel.contentType?.isHTML ?? false {
                        Button("Open in Browser") {
                            isWebViewOpen = true
                        }
                    } else {
                        EmptyView()
                    }
                }
#else
                RichTextView(viewModel: viewModel)
#endif
            }
        } else {
            SpinnerView(viewModel: .init(title: "Rendering...", details: nil))
        }
    }
}

// MARK: - Preview

#if DEBUG
struct NetworkInspectorResponseView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FileViewer(viewModel: .init(title: "Response", context: .init(contentType: "application/json", originalSize: 1200), data: { MockJSON.allPossibleValues }))
                .previewDisplayName("JSON")

            FileViewer(viewModel: .init(title: "Response", context: .init(contentType: "image/png", originalSize: 219543), data: { MockTask.octocat.responseBody }))
                .previewDisplayName("Image")

            FileViewer(viewModel: .init(title: "Response", context: .init(contentType: "application/html", originalSize: 1200), data: { MockTask.profile.responseBody }))
                .previewDisplayName("HTML")

            FileViewer(viewModel: .init(title: "Response", context: .init(contentType: "application/x-www-form-urlencoded", originalSize: 1200), data: { MockTask.patchRepo.originalRequest.httpBody ?? Data() }))
                .previewDisplayName("Query Items")

            FileViewer(viewModel: .init(title: "Response", context: .init(contentType: "application/pdf", originalSize: 1000), data: { mockPDF }))
                .previewDisplayName("PDF")
        }
    }
}

enum MockJSON {
    static let allPossibleValues = """
    {
      "actors": [
        {
          "name": "Tom Cruise",
          "age": 56,
          "Born At": "Syracuse, NY",
          "Birthdate": "July 3, 1962",
          "photo": "https://jsonformatter.org/img/tom-cruise.jpg",
          "wife": null,
          "weight": 67.5,
          "hasChildren": true,
          "hasGreyHair": false,
          "children": [
            "Suri",
            "Isabella Jane",
            "Connor"
          ]
        },
        {
          "name": "Robert Downey Jr.",
          "age": 53,
          "born At": "New York City, NY",
          "birthdate": "April 4, 1965",
          "photo": "https://jsonformatter.org/img/Robert-Downey-Jr.jpg",
          "wife": "Susan Downey",
          "weight": 77.1,
          "hasChildren": true,
          "hasGreyHair": false,
          "children": [
            "Indio Falconer",
            "Avri Roel",
            "Exton Elias"
          ]
        }
      ]
    }
    """.data(using: .utf8)!
}
#endif

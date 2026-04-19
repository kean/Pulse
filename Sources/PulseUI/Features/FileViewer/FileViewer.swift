// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(tvOS) || os(macOS) || os(watchOS) || os(visionOS)

import SwiftUI
import Pulse

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct FileViewer: View {
    @ObservedObject var viewModel: FileViewerViewModel

#if os(tvOS)
    var body: some View {
        HStack {
            contents
            Spacer()
        }
    }
#else
    var body: some View {
            contents
    }
#endif

    @ViewBuilder
    private var contents: some View {
        switch viewModel.contents {
        case .image(let viewModel):
            ScrollView {
                ImageViewer(viewModel: viewModel)
            }
#if os(iOS) || os(visionOS)
        case .pdf(let document):
            PDFKitRepresentedView(document: document)
                .edgesIgnoringSafeArea(.all)
#elseif os(macOS)
        case .pdf:
            PlaceholderView(imageName: "doc.richtext", title: "PDF Preview", subtitle: "PDF preview is not available")
#endif
        case .other(let viewModel):
            RichTextView(viewModel: viewModel)
        }
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
#Preview("JSON") {
    PreviewContainer {
        FileViewer(viewModel: .init(title: "Response", context: .init(contentType: "application/json", originalSize: 1200), data: { MockJSON.allPossibleValues }))
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
#Preview("Image") {
    PreviewContainer {
        FileViewer(viewModel: .init(title: "Response", context: .init(contentType: "image/png", originalSize: 219543), data: { MockTask.octocat.responseBody }))
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
#Preview("HTML") {
    PreviewContainer {
        FileViewer(viewModel: .init(title: "Response", context: .init(contentType: "application/html", originalSize: 1200), data: { MockTask.profile.responseBody }))
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
#Preview("Query Items") {
    PreviewContainer {
        FileViewer(viewModel: .init(title: "Response", context: .init(contentType: "application/x-www-form-urlencoded", originalSize: 1200), data: { MockTask.patchRepo.originalRequest.httpBody ?? Data() }))
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
#Preview("PDF") {
    PreviewContainer {
        FileViewer(viewModel: .init(title: "Response", context: .init(contentType: "application/pdf", originalSize: 1000), data: { mockPDF }))
    }
}

private struct PreviewContainer<Content: View>: View {
    @ViewBuilder var contents: () -> Content

    var body: some View {
#if os(iOS) || os(visionOS)
        NavigationView {
            contents()
        }
#else
        contents()
#endif
    }
}

#endif

#endif

#if DEBUG

package enum MockJSON {
    package static let allPossibleValues = """
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

// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

struct FileViewer: View {
    @ObservedObject var viewModel: FileViewerViewModel
    var onToggleExpanded: (() -> Void)?

#if os(iOS) || os(macOS)
    var body: some View {
        contents
            .onAppear { viewModel.render() }
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
                RichTextView(viewModel: viewModel, onToggleExpanded: onToggleExpanded)
            case .image(let image):
                makeImageView(with: image)
            case .other(let viewModel):
                RichTextView(viewModel: viewModel, onToggleExpanded: onToggleExpanded)
            }
        } else {
            SpinnerView(viewModel: .init(title: "Rendering...", details: nil))
        }
    }

    private func makeImageView(with image: UXImage) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    KeyValueSectionView(viewModel: KeyValueSectionViewModel(title: "Image", color: .pink, items: [
                        ("Width", "\(image.cgImage?.width ?? 0) px"),
                        ("Height", "\(image.cgImage?.height ?? 0) px")
                    ])).fixedSize()
                    Spacer()
                }

                Divider()

                Image(uxImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                Spacer()
            }.padding()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct NetworkInspectorResponseView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FileViewer(viewModel: .init(title: "Response", data: { MockJSON.allPossibleValues }))
                .previewDisplayName("JSON")

            FileViewer(viewModel: .init(title: "Response", data: { MockTask.octocat.responseBody }))
                .previewDisplayName("Image")

            FileViewer(viewModel: .init(title: "Response", data: { mockHTML }))
                .previewDisplayName("HTML")
        }
    }
}

private let mockHTML = """
<!DOCTYPE html>
<html>
<body>

<h1>My First Heading</h1>
<p>My first paragraph.</p>

</body>
</html>
""".data(using: .utf8)!

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

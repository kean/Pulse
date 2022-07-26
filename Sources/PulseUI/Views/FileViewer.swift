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
#if os(iOS)
            NavigationView {
                FileViewer(viewModel: mockModel)
                    .navigationBarTitle("Response")
            }
            .previewDisplayName("Light")
            .environment(\.colorScheme, .light)
#else
            FileViewer(viewModel: mockModel)
                .previewDisplayName("Light")
                .environment(\.colorScheme, .light)
#endif

            FileViewer(viewModel: .init(title: "Response", data: { mockImage }))
                .previewDisplayName("Image")
                .environment(\.colorScheme, .light)

            FileViewer(viewModel: .init(title: "Response", data: { mockHTML }))
                .previewDisplayName("HTML")
                .environment(\.colorScheme, .light)

            FileViewer(viewModel: mockModel)
                .previewDisplayName("Dark")
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)

        }
    }
}

private let mockModel = FileViewerViewModel(title: "Response", data: { MockJSON.allPossibleValues })

private let mockHTML = """
<!DOCTYPE html>
<html>
<body>

<h1>My First Heading</h1>
<p>My first paragraph.</p>

</body>
</html>
""".data(using: .utf8)!
#endif

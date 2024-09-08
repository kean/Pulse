// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ImageViewer: View {
    let viewModel: ImagePreviewViewModel

    var body: some View {
        VStack(spacing: 16) {
            ImageThumbnailView(viewModel: viewModel)

            HStack {
                TextView(string: TextRenderer().render(viewModel.info))
                Spacer()
            }

            Spacer()
        }.padding()
    }
}

struct ImageThumbnailView: View {
    let viewModel: ImagePreviewViewModel

    var body: some View {
        Image(uxImage: viewModel.image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: viewModel.image.size.width * 0.5, maxHeight: viewModel.image.size.height * 0.5)
            .border(Color.separator, width: 0.5)
    }
}

struct ImagePreviewViewModel {
    let image: UXImage
    let info: KeyValueSectionViewModel
    let context: FileViewerViewModelContext

    init(image: UXImage, data: Data, context: FileViewerViewModelContext) {
        func intValue(for key: String) -> Int? {
            context.metadata?[key].flatMap { Int($0) }
        }

        let isShowingOriginal = Int64(data.count) == context.originalSize
        let originalImageSize: CGSize?
        if isShowingOriginal {
            originalImageSize = image.size
        } else if context.isResponse {
            if let width = intValue(for: "ResponsePixelWidth"),
               let height = intValue(for: "ResponsePixelHeight") {
                originalImageSize = CGSize(width: width, height: height)
            } else {
                originalImageSize = nil
            }
        } else {
            if let width = intValue(for: "RequestPixelWidth"),
               let height = intValue(for: "RequestPixelHeight") {
                originalImageSize = CGSize(width: width, height: height)
            } else {
                originalImageSize = nil
            }
        }

        let info: [(String, String?)] = [
            ("Resolution", originalImageSize.map(formattedResolution)),
            ("Size", ByteCountFormatter.string(fromByteCount: context.originalSize)),
            ("Type", context.contentType?.rawValue),
            ("Stored", isShowingOriginal ? "Original" : "Thumbnail (\(formattedResolution(with: image.size)))")
        ]

        self.image = image
        self.info = KeyValueSectionViewModel(title: "Image", color: .pink, items: info)
        self.context = context
    }
}

private extension CGSize {
    func scaled(by scale: CGFloat) -> CGSize {
        CGSize(width: width * scale, height: width * height)
    }
}

private func formattedResolution(with pixelSize: CGSize) -> String {
    "\(Int(pixelSize.width)) × \(Int(pixelSize.height)) px"
}

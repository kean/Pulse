// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

struct NetworkInspectorResponseView: View {
    let viewModel: NetworkInspectorResponseViewModel
    var onToggleExpanded: (() -> Void)?

#if os(iOS)
    var body: some View {
        contents
            .edgesIgnoringSafeArea(.bottom)
    }
#elseif os(macOS)
    var body: some View {
        contents
    }
#elseif os(watchOS)
    var body: some View {
        ScrollView {
            contents
        }
    }
#elseif os(tvOS)
    var body: some View {
        HStack {
            contents
            Spacer()
        }
    }
#endif

    @ViewBuilder
    private var contents: some View {
        switch viewModel.contents {
        case .json(let viewModel):
            RichTextView(viewModel: viewModel, onToggleExpanded: onToggleExpanded)
        case .image(let image):
            makeImageView(with: image)
        case .other(let viewModel):
            RichTextView(viewModel: viewModel, onToggleExpanded: onToggleExpanded)
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
                NetworkInspectorResponseView(viewModel: mockModel)
                    .navigationBarTitle("Response")
            }
            .previewDisplayName("Light")
            .environment(\.colorScheme, .light)
#else
            NetworkInspectorResponseView(viewModel: mockModel)
                .previewDisplayName("Light")
                .environment(\.colorScheme, .light)
#endif

            NetworkInspectorResponseView(viewModel: .init(title: "Response", data: mockImage))
                .previewDisplayName("Image")
                .environment(\.colorScheme, .light)

            NetworkInspectorResponseView(viewModel: .init(title: "Response", data: mockHTML))
                .previewDisplayName("HTML")
                .environment(\.colorScheme, .light)

            NetworkInspectorResponseView(viewModel: mockModel)
                .previewDisplayName("Dark")
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)

        }
    }
}

private let mockModel = NetworkInspectorResponseViewModel(title: "Response", data: MockJSON.allPossibleValues)

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

// MARK: - ViewModel

final class NetworkInspectorResponseViewModel {
    let title: String
    private let getData: () -> Data

    lazy var contents: Contents = {
        let data = getData()
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
            return .json(RichTextViewModel(json: json))
        } else if let image = UXImage(data: data) {
            return .image(image)
        } else {
            let string = String(data: data, encoding: .utf8) ?? "Data \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))"
            return .other(RichTextViewModel(string: string))
        }
    }()

    init(title: String, data: @autoclosure @escaping () -> Data) {
        self.title = title
        self.getData = data
    }

    enum Contents {
        case json(RichTextViewModel)
        case image(UXImage)
        case other(RichTextViewModel)
    }
}

private extension Data {
    var localizedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }
}

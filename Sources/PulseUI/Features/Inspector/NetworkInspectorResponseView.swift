// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

struct NetworkInspectorResponseView: View {
    let viewModel: NetworkInspectorResponseViewModel

    @State private var isShowingShareSheet = false

    #if os(iOS)
    var body: some View {
        contents
            .navigationBarTitle(viewModel.title)
            .navigationBarItems(trailing: ShareButton { isShowingShareSheet = true })
            .sheet(isPresented: $isShowingShareSheet) {
                ShareView(activityItems: [viewModel.prepareForSharing()])
            }
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
    #else
    var body: some View {
        contents
    }
    #endif

    @ViewBuilder
    private var contents: some View {
        if let json = try? JSONSerialization.jsonObject(with: viewModel.data, options: []) {
            RichTextView(viewModel: .init(json: json))
        } else if let image = UXImage(data: viewModel.data) {
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
        } else {
            /// TODO: remove inefficiency where we scan this twice
            RichTextView(viewModel: .init(data: viewModel.data))
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
    lazy var data: Data = getData()
    private let getData: () -> Data

    init(title: String, data: @autoclosure @escaping () -> Data) {
        self.title = title
        self.getData = data
    }

    func prepareForSharing() -> Any {
        if let image = UXImage(data: data) {
            return image
        } else if let string = String(data: data, encoding: .utf8) {
            return string
        } else {
            return data
        }
    }
}

private extension Data {
    var localizedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }
}

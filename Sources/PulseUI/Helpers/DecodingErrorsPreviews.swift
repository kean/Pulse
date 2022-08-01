// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import SwiftUI
import PulseCore

#if os(iOS) || os(macOS)

#if DEBUG

struct DecodingErrors_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            fileViewer(error: typeMismatchError())
                .previewDisplayName("Type Mismatch (Object)")
            fileViewer(error: typeMismatchErrorInArray())
                .previewDisplayName("Type Mismatch (Array)")
            fileViewer(error: valueNotFoundError())
                .previewDisplayName("Value Not Found")
            fileViewer(error: keyNotFound())
                .previewDisplayName("Key Not Found")
            fileViewer(error: dataCorrupted())
                .previewDisplayName("Data Corrupted")

        }
    }

    private static func fileViewer(error: NetworkLoggerDecodingError) -> some View {
        FileViewer(viewModel: .init(title: "Response", contentType: "application/json", originalSize: 1200, error: error, data: { MockJSON.allPossibleValues }))
    }
}

private func typeMismatchError() -> NetworkLoggerDecodingError {
    struct JSON: Decodable {
        let actors: [Actor]

        struct Actor: Decodable {
            let age: String
        }
    }
    return getError(JSON.self)
}

private func typeMismatchErrorInArray() -> NetworkLoggerDecodingError {
    struct JSON: Decodable {
        let actors: [Actor]

        struct Actor: Decodable {
            let children: [Int]
        }
    }
    return getError(JSON.self)
}

private func valueNotFoundError() -> NetworkLoggerDecodingError {
    struct JSON: Decodable {
        let actors: [Actor]

        struct Actor: Decodable {
            let wife: String
        }
    }
    return getError(JSON.self)
}

private func keyNotFound() -> NetworkLoggerDecodingError {
    struct JSON: Decodable {
        let actors: [Actor]

        struct Actor: Decodable {
            let lastName: String
        }
    }
    return getError(JSON.self)
}

private func dataCorrupted() -> NetworkLoggerDecodingError {
    struct JSON: Decodable {
        let actors: [Actor]

        struct Actor: Decodable {
            let name: URL
        }
    }
    return getError(JSON.self)
}

private func getError<T: Decodable>(_ type: T.Type) -> NetworkLoggerDecodingError {
    do {
        _ = try JSONDecoder().decode(type, from: MockJSON.allPossibleValues)
        fatalError()
    } catch {
        return NetworkLoggerDecodingError(error as! DecodingError)
    }
}

#endif

#endif

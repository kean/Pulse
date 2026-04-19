// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS)

#if DEBUG

import Foundation
import SwiftUI
import Pulse

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
#Preview("Type Mismatch (Object)") {
    fileViewer(error: typeMismatchError())
}

#Preview("Type Mismatch (Array)") {
    fileViewer(error: typeMismatchErrorInArray())
}

#Preview("Value Not Found") {
    fileViewer(error: valueNotFound())
}

#Preview("Key Not Found") {
    fileViewer(error: keyNotFound())
}

#Preview("Data Corrupted") {
    fileViewer(error: dataCorrupted())
}

@ViewBuilder
private func fileViewer(error: NetworkLogger.DecodingError) -> some View {
    if #available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *) {
        let viewer = FileViewer(viewModel: .init(title: "Response", context: .init(contentType: .init(rawValue: "application/json"), originalSize: 1200, error: error), data: { MockJSON.allPossibleValues }))
        NavigationView {
            viewer
        }
    }
}

private func typeMismatchError() -> NetworkLogger.DecodingError {
    struct JSON: Decodable {
        let actors: [Actor]

        struct Actor: Decodable {
            let age: String
        }
    }
    return getError(JSON.self)
}

private func typeMismatchErrorInArray() -> NetworkLogger.DecodingError {
    struct JSON: Decodable {
        let actors: [Actor]

        struct Actor: Decodable {
            let children: [Int]
        }
    }
    return getError(JSON.self)
}

private func valueNotFound() -> NetworkLogger.DecodingError {
    struct JSON: Decodable {
        let actors: [Actor]

        struct Actor: Decodable {
            let wife: String
        }
    }
    return getError(JSON.self)
}

private func keyNotFound() -> NetworkLogger.DecodingError {
    struct JSON: Decodable {
        let actors: [Actor]

        struct Actor: Decodable {
            let lastName: String
        }
    }
    return getError(JSON.self)
}

private func dataCorrupted() -> NetworkLogger.DecodingError {
    struct JSON: Decodable {
        let actors: [Actor]

        struct Actor: Decodable {
            let name: URL
        }
    }
    return getError(JSON.self)
}

private func getError<T: Decodable>(_ type: T.Type) -> NetworkLogger.DecodingError {
    do {
        _ = try JSONDecoder().decode(type, from: MockJSON.allPossibleValues)
        fatalError()
    } catch {
        return NetworkLogger.DecodingError(error as! DecodingError)
    }
}

#endif

#endif

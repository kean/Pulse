// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct AlertViewModel: Hashable, Identifiable {
    var id: String = UUID().uuidString
    let title: String
    let message: String
}

enum AppViewModelError: Error, LocalizedError {
    case failedToFindLogsStore(url: URL)

    var errorDescription: String? {
        switch self {
        case .failedToFindLogsStore(let url):
            return "Failed to find a Pulse store at the given URL \(url)"
        }
    }
}

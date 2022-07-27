// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(iOS) || os(macOS) || os(tvOS)

extension PlaceholderView {
    static func make(viewModel: ConsoleViewModel) -> PlaceholderView {
        let message: String
        if viewModel.searchCriteria.isDefaultSearchCriteria {
            if viewModel.searchCriteria.criteria.dates.isCurrentSessionOnly {
                message = "There are no messages in the current session."
            } else {
                message = "There are no stored messages."
            }
        } else {
            message = "There are no messages for the selected filters."
        }
        return PlaceholderView(imageName: "message", title: "No Messages", subtitle: message)
    }

    static func make(viewModel: NetworkViewModel) -> PlaceholderView {
        let message: String
        if viewModel.searchCriteria.isDefaultSearchCriteria {
            if viewModel.searchCriteria.criteria.dates.isCurrentSessionOnly {
                message = "There are no network requests in the current session."
            } else {
                message = "There are no stored network requests."
            }
        } else {
            message = "There are no network requests for the selected filters."
        }
        return PlaceholderView(imageName: "network", title: "No Requests", subtitle: message)
    }
}

#endif

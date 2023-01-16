// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation

#warning("when you are typing search, add -headers contains, -requety body: contains, etc")
#warning("how to view all suggestions?")
#warning("how to surface these to the user?")
#warning("add support for basic wildcards")
#warning("add a way to enable regex")

#warning("remove ConsoleSearchToken and have separate filters and scope")

#warning("better icons & titles for tokens")

// network:
//
// - "url" <value>
// - "host" = <value> (+add commons hosts)
// - "domain" = <value>
// - "method" <value>
// - "path" <value>
// - "scheme" <value>
// - "duration" ">=" "<=" <value>
// - "\(kind)" "contains" <value>
// - "type" data/download/upload/stream/socket
// - "cookies" empty/non-empty/contains
// - "timeout" >= <=
// - "error"
// - "size" >= <= <value>
// - "error code" <value>
// - "error decoding failed"
// - "content-type" <value>
// - "cached"
// - "redirect"
// - "pins"
//
// message:
//
// - "label" <value>
// - "log level" or "level"
// - "metadata"
// - "file" <value>
enum ConsoleSearchToken: Identifiable, Hashable {
    var id: ConsoleSearchToken { self }

    case filter(ConsoleSearchFilter)
    case scope(ConsoleSearchScope)

    var systemImage: String {
        switch self {
        case .filter: return "line.3.horizontal.decrease.circle.fill"
        case .scope: return "magnifyingglass.circle.fill"
        }
    }

    var title: String {
        switch self {
        case .filter(let filter):
            switch filter {
            case .statusCode(let statusCode):
                guard statusCode.values.count > 0 else {
                    return "Status Code" // Should never happen
                }
                let title = statusCode.values[0].title
                return statusCode.values.count > 1 ? title + "…" : title
            }
        case .scope(let scope):
            return scope.title
        }
    }
}

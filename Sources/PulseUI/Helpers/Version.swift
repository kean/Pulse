// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse

struct Version: Comparable, Sendable {
    let major: Int
    let minor: Int
    let patch: Int

    init(_ major: Int, _ minor: Int, _ patch: Int) {
        precondition(major >= 0 && minor >= 0 && patch >= 0, "Negative versioning is invalid.")
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    var description: String {
        "\(major).\(minor).\(patch)"
    }

    // MARK: Comparable

    static func == (lhs: Version, rhs: Version) -> Bool {
        !(lhs < rhs) && !(lhs > rhs)
    }

    static func < (lhs: Version, rhs: Version) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    init?(_ string: String) {
        guard string.allSatisfy(\.isASCII) else { return nil }
        let components = string.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3,
              let major = Int(components[0]),
              let minor = Int(components[1]),
              let patch = Int(components[2]) else {
            return nil
        }
        self.major = major
        self.minor = minor
        self.patch = patch
    }
}

// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

struct Version: Comparable, LosslessStringConvertible, Codable, Sendable {
    let major: Int
    let minor: Int
    let patch: Int

    init(_ major: Int, _ minor: Int, _ patch: Int) {
        precondition(major >= 0 && minor >= 0 && patch >= 0, "Negative versioning is invalid.")
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    // MARK: Comparable

    static func == (lhs: Version, rhs: Version) -> Bool {
        !(lhs < rhs) && !(lhs > rhs)
    }

    static func < (lhs: Version, rhs: Version) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    init(string: String) throws {
        guard let version = Version(string) else {
            throw LoggerStore.Error.unknownError // Should never happen
        }
        self = version
    }

    // MARK: LosslessStringConvertible

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

    var description: String {
        "\(major).\(minor).\(patch)"
    }

    // MARK: Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard let version = Version(try container.decode(String.self)) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid version number format")
        }
        self = version
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }
}

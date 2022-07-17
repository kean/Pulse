// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

struct Version {
    let major: Int
    let minor: Int
    let patch: Int
    let prereleaseIdentifiers: [String]

    init(_ major: Int, _ minor: Int, _ patch: Int, prereleaseIdentifiers: [String] = []) {
        precondition(major >= 0 && minor >= 0 && patch >= 0, "Negative versioning is invalid.")
        precondition(
            prereleaseIdentifiers.allSatisfy {
                $0.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
            },
            #"Pre-release identifiers can contain only ASCII alphanumeric characters and "-"."#
        )
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prereleaseIdentifiers = prereleaseIdentifiers
    }
}

extension Version: Comparable {
    @inlinable
    static func == (lhs: Version, rhs: Version) -> Bool {
        !(lhs < rhs) && !(lhs > rhs)
    }

    static func < (lhs: Version, rhs: Version) -> Bool {
        let lhsComparators = [lhs.major, lhs.minor, lhs.patch]
        let rhsComparators = [rhs.major, rhs.minor, rhs.patch]

        if lhsComparators != rhsComparators {
            return lhsComparators.lexicographicallyPrecedes(rhsComparators)
        }

        guard lhs.prereleaseIdentifiers.count > 0 else {
            return false // Non-prerelease lhs >= potentially prerelease rhs
        }

        guard rhs.prereleaseIdentifiers.count > 0 else {
            return true // Prerelease lhs < non-prerelease rhs
        }

        for (lhsPrereleaseIdentifier, rhsPrereleaseIdentifier) in zip(lhs.prereleaseIdentifiers, rhs.prereleaseIdentifiers) {
            if lhsPrereleaseIdentifier == rhsPrereleaseIdentifier {
                continue
            }

            let lhsNumericPrereleaseIdentifier = Int(lhsPrereleaseIdentifier)
            let rhsNumericPrereleaseIdentifier = Int(rhsPrereleaseIdentifier)

            if let lhsNumericPrereleaseIdentifier = lhsNumericPrereleaseIdentifier,
               let rhsNumericPrereleaseIdentifier = rhsNumericPrereleaseIdentifier {
                return lhsNumericPrereleaseIdentifier < rhsNumericPrereleaseIdentifier
            } else if lhsNumericPrereleaseIdentifier != nil {
                return true
            } else if rhsNumericPrereleaseIdentifier != nil {
                return false
            } else {
                return lhsPrereleaseIdentifier < rhsPrereleaseIdentifier
            }
        }

        return lhs.prereleaseIdentifiers.count < rhs.prereleaseIdentifiers.count
    }
}

extension Version: LosslessStringConvertible {
    init?(_ versionString: String) {
        guard versionString.allSatisfy(\.isASCII) else { return nil }

        let metadataDelimiterIndex = versionString.firstIndex(of: "+")
        let prereleaseDelimiterIndex = versionString[..<(metadataDelimiterIndex ?? versionString.endIndex)].firstIndex(of: "-")

        let versionCore = versionString[..<(prereleaseDelimiterIndex ?? metadataDelimiterIndex ?? versionString.endIndex)]
        let versionCoreIdentifiers = versionCore.split(separator: ".", omittingEmptySubsequences: false)

        guard
            versionCoreIdentifiers.count == 3,
                let major = Int(versionCoreIdentifiers[0]),
            let minor = Int(versionCoreIdentifiers[1]),
            let patch = Int(versionCoreIdentifiers[2])
        else { return nil }

        self.major = major
        self.minor = minor
        self.patch = patch

        if let prereleaseDelimiterIndex = prereleaseDelimiterIndex {
            let prereleaseStartIndex = versionString.index(after: prereleaseDelimiterIndex)
            let prereleaseIdentifiers = versionString[prereleaseStartIndex..<(metadataDelimiterIndex ?? versionString.endIndex)].split(separator: ".", omittingEmptySubsequences: false)
            guard prereleaseIdentifiers.allSatisfy({ $0.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" })}) else { return nil }
            self.prereleaseIdentifiers = prereleaseIdentifiers.map { String($0) }
        } else {
            self.prereleaseIdentifiers = []
        }
    }
}


extension Version: CustomStringConvertible {
    var description: String {
        var base = "\(major).\(minor).\(patch)"
        if !prereleaseIdentifiers.isEmpty {
            base += "-" + prereleaseIdentifiers.joined(separator: ".")
        }
        return base
    }
}

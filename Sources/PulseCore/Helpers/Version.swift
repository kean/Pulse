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
            #"Pre-release identifiers can contain only ASCII alpha-numeric characters and "-"."#
        )
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prereleaseIdentifiers = prereleaseIdentifiers
    }
}

extension Version: Comparable {
    // Although `Comparable` inherits from `Equatable`, it does not provide a new default implementation of `==`, but instead uses `Equatable`'s default synthesised implementation. The compiler-synthesised `==`` is composed of [member-wise comparisons](https://github.com/apple/swift-evolution/blob/main/proposals/0185-synthesize-equatable-hashable.md#implementation-details), which leads to a false `false` when 2 semantic versions differ by only their build metadata identifiers, contradicting SemVer 2.0.0's [comparison rules](https://semver.org/#spec-item-10).

    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Equality is the inverse of inequality. For any values `a` and `b`, `a ==
    /// b` implies that `a != b` is `false`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    ///
    /// - Returns: A boolean value indicating the result of the equality test.
    @inlinable
    static func == (lhs: Version, rhs: Version) -> Bool {
        !(lhs < rhs) && !(lhs > rhs)
    }

    /// Returns a Boolean value indicating whether the value of the first
    /// argument is less than that of the second argument.
    ///
    /// The precedence is determined according to rules described in the [Semantic Versioning 2.0.0](https://semver.org) standard, paragraph 11.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
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

            // Check if either of the 2 pre-release identifiers is numeric.
            let lhsNumericPrereleaseIdentifier = Int(lhsPrereleaseIdentifier)
            let rhsNumericPrereleaseIdentifier = Int(rhsPrereleaseIdentifier)

            if let lhsNumericPrereleaseIdentifier = lhsNumericPrereleaseIdentifier,
               let rhsNumericPrereleaseIdentifier = rhsNumericPrereleaseIdentifier {
                return lhsNumericPrereleaseIdentifier < rhsNumericPrereleaseIdentifier
            } else if lhsNumericPrereleaseIdentifier != nil {
                return true // numeric pre-release < non-numeric pre-release
            } else if rhsNumericPrereleaseIdentifier != nil {
                return false // non-numeric pre-release > numeric pre-release
            } else {
                return lhsPrereleaseIdentifier < rhsPrereleaseIdentifier
            }
        }

        return lhs.prereleaseIdentifiers.count < rhs.prereleaseIdentifiers.count
    }
}

extension Version: LosslessStringConvertible {
    init?(_ versionString: String) {
        // SemVer 2.0.0 allows only ASCII alphanumerical characters and "-" in the version string, except for "." and "+" as delimiters. ("-" is used as a delimiter between the version core and pre-release identifiers, but it's allowed within pre-release and metadata identifiers as well.)
        // Alphanumerics check will come later, after each identifier is split out (i.e. after the delimiters are removed).
        guard versionString.allSatisfy(\.isASCII) else { return nil }

        let metadataDelimiterIndex = versionString.firstIndex(of: "+")
        // SemVer 2.0.0 requires that pre-release identifiers come before build metadata identifiers
        let prereleaseDelimiterIndex = versionString[..<(metadataDelimiterIndex ?? versionString.endIndex)].firstIndex(of: "-")

        let versionCore = versionString[..<(prereleaseDelimiterIndex ?? metadataDelimiterIndex ?? versionString.endIndex)]
        let versionCoreIdentifiers = versionCore.split(separator: ".", omittingEmptySubsequences: false)

        guard
            versionCoreIdentifiers.count == 3,
            // Major, minor, and patch versions must be ASCII numbers, according to the semantic versioning standard.
            // Converting each identifier from a substring to an integer doubles as checking if the identifiers have non-numeric characters.
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

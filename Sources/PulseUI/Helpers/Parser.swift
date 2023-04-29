// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import Foundation

// A simple parser combinators implementation. "Combinators" mean higher-order
// functions that take one or more parsers as input and produce new parsers like
// output.
//
// A parser from https://github.com/kean/Regex

// MARK: - Parser

struct Parser<A> {
    /// Parses the given string. Returns the matched element `A` and the
    /// remaining substring if the match is successful. Returns `nil` otherwise.
    let parse: (_ string: Substring) throws -> (A, Substring)?
}

extension Parser {
    func parse(_ string: String) throws -> A? {
        try parse(string[...])?.0
    }
}

// MARK: - Parser (Predefined)

struct Parsers {}

extension Parsers {
    /// Matches the given string.
    static func string(_ word: String) -> Parser<Void> {
        Parser { s in
            s.hasPrefix(word) ? ((), s.dropFirst(word.count)) : nil
        }
    }

    static func fuzzy(_ word: String, confidence: Confidence = 0.6) -> Parser<Confidence> {
        char(from: .letters).oneOrMore
            .map { String($0).fuzzyMatch(word) }
            .filter { $0 > confidence }
    }

    /// Consumes any number of whitespaces after the previous match.
    static let whitespaces = char(from: .whitespaces).zeroOrMore.map { _ in () }

    /// Matches any single character.
    static let char = Parser<Character> { s in
        s.isEmpty ? nil : (s.first!, s.dropFirst())
    }

    /// Matches a character if the given string doesn't contain it.
    static func char(excluding string: String) -> Parser<Character> {
        char.filter { !string.contains($0) }
    }

    /// Matches any character contained in the given string.
    static func char(from string: String) -> Parser<Character> {
        char.filter(string.contains)
    }

    static func char(from characterSet: CharacterSet) -> Parser<Character> {
        char.filter(characterSet.contains)
    }

    /// Matches characters while the given string doesn't contain them.
    static func string(excluding string: String) -> Parser<String> {
        char(excluding: string).oneOrMore.map { String($0) }
    }

    /// Parsers a natural number or zero. Valid inputs: "0", "1", "10".
    static let int = digit.oneOrMore.map { Int(String($0)) }

    /// Matches a single digit.
    static let digit = char.filter(CharacterSet.decimalDigits.contains)
}

extension Parser: ExpressibleByStringLiteral, ExpressibleByUnicodeScalarLiteral, ExpressibleByExtendedGraphemeClusterLiteral where A == Void {
    // Unfortunately had to add these explicitly supposably because of the
    // conditional conformance limitations.
    typealias ExtendedGraphemeClusterLiteralType = StringLiteralType
    typealias UnicodeScalarLiteralType = StringLiteralType
    typealias StringLiteralType = String

    init(stringLiteral value: String) {
        self = Parsers.string(value)
    }
}

// MARK: - Parser (Combinators)

extension Parsers {

    /// Matches only if both of the given parsers produced a result.
    static func zip<A, B>(_ a: Parser<A>, _ b: Parser<B>) -> Parser<(A, B)> {
        a.flatMap { matchA in b.map { matchB in (matchA, matchB) } }
    }

    static func zip<A, B, C>(_ a: Parser<A>, _ b: Parser<B>, _ c: Parser<C>) -> Parser<(A, B, C)> {
        zip(a, zip(b, c)).map { a, bc in (a, bc.0, bc.1) }
    }

    /// Returns the first match or `nil` if no matches are found.
    static func oneOf<A>(_ parsers: Parser<A>...) -> Parser<A> {
        oneOf(parsers)
    }

    /// Returns the first match or `nil` if no matches are found.
    static func oneOf<A>(_ parsers: [Parser<A>]) -> Parser<A> {
        precondition(!parsers.isEmpty)
        return Parser<A> { str -> (A, Substring)? in
            for parser in parsers {
                if let match = try parser.parse(str) {
                    return match
                }
            }
            return nil
        }
    }
}

extension Parser {
    func map<B>(_ transform: @escaping (A) throws -> B?) -> Parser<B> {
        flatMap { match in
            Parser<B> { str in
                (try transform(match)).map { ($0, str) }
            }
        }
    }

    func flatMap<B>(_ transform: @escaping (A) throws -> Parser<B>) -> Parser<B> {
        Parser<B> { str in
            guard let (a, str) = try self.parse(str) else { return nil }
            return try transform(a).parse(str)
        }
    }

    func filter(_ predicate: @escaping (A) -> Bool) -> Parser<A> {
        map { predicate($0) ? $0 : nil }
    }
}

// MARK: - Parser (Quantifiers)

extension Parser {
    /// Matches the given parser zero or more times.
    var zeroOrMore: Parser<[A]> {
        Parser<[A]> { str in
            var str = str
            var matches = [A]()
            while let (match, newStr) = try self.parse(str) {
                matches.append(match)
                str = newStr
            }
            return (matches, str)
        }
    }

    /// Matches the given parser one or more times.
    var oneOrMore: Parser<[A]> {
        zeroOrMore.map { $0.isEmpty ? nil : $0 }
    }

    /// Matches of the parser produces no matches (inverts the parser).
    var zero: Parser<Void> {
        map { _ in nil }
    }
}

// MARK: - Parser (Optional)

func optional<A>(_ parser: Parser<A>) -> Parser<A?> {
    Parser<A?> { str -> (A?, Substring)? in
          guard let match = try parser.parse(str) else {
              return (nil, str) // Return empty match without consuming any characters
          }
          return match
      }
}

func optional(_ parser: Parser<Void>) -> Parser<Bool> {
    Parser<Bool> { str -> (Bool, Substring)? in
        guard let match = try parser.parse(str) else {
            return (false, str) // Return empty match without consuming any characters
        }
        return (true, match.1)
    }
}

// MARK: - Parser (Misc)

extension Parsers {

    /// Succeeds when input is empty.
    static let end = Parser<Void> { str in str.isEmpty ? ((), str) : nil }
}

// MARK: - Parser (Operators)

infix operator *> : CombinatorPrecedence
infix operator <* : CombinatorPrecedence
infix operator <*> : CombinatorPrecedence

func *> <A, B>(_ lhs: Parser<A>, _ rhs: Parser<B>) -> Parser<B> {
    Parsers.zip(lhs, rhs).map { $0.1 }
}

func <* <A, B>(_ lhs: Parser<A>, _ rhs: Parser<B>) -> Parser<A> {
    Parsers.zip(lhs, rhs).map { $0.0 }
}

// Combines two parsers and keep the results of both.
func <*> <A, B>(_ lhs: Parser<A>, _ rhs: Parser<B>) -> Parser<(A, B)> {
    Parsers.zip(lhs, rhs)
}

precedencegroup CombinatorPrecedence {
    associativity: left
    higherThan: DefaultPrecedence
}

// MARK: - Extensions

private extension CharacterSet {
    func contains(_ c: Character) -> Bool {
        c.unicodeScalars.allSatisfy(contains)
    }
}

private extension Substring {
    mutating func consume(while closure: (Character) -> Bool) {
        while let first = first, closure(first) {
            removeFirst()
        }
    }
}

struct Confidence: Hashable, Comparable, ExpressibleByFloatLiteral {
    let rawValue: Float

    init(floatLiteral value: FloatLiteralType) {
        self.rawValue = max(0, min(1, Float(value)))
    }

    init(_ rawValue: Float) {
        self.rawValue = max(0, min(1, rawValue))
    }

    static func < (lhs: Confidence, rhs: Confidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension String {
    static func fuzzyMatch(values: [String], from source: Set<String>) -> [(String, Confidence)] {
        let suggested = values.flatMap { value in
            source.map { ($0, $0.fuzzyMatch(value)) }
        }
        return Array(suggested.filter({ $0.1 > 0.2 })
            .sorted(by: { $0.1 > $1.1 })
            .prefix(2))
    }

    /// A fuzzy check for the given word. Always consumes a word. Returns
    /// a confidence level in a range of 0...1.
    func fuzzyMatch(_ target: String) -> Confidence {
        guard !self.isEmpty && !target.isEmpty else {
            return 0.0
        }
        let lhs = self.lowercased()
        let rhs = target.lowercased()

        let prefixCount = min(lhs.count, rhs.count)
        let countDiff = Float(abs(count - target.count))
        let countWeight = 1.0 - (countDiff / Float(max(count, target.count)))
        if hasPrefix(target) {
            return Confidence(0.8 + (countWeight * 0.2))
        }
        if  contains(target) {
            return Confidence(0.7 + (countWeight * 0.2))
        }
        let fullDistance = lhs.distance(to: rhs)
        let prefixDistance = String(lhs.prefix(prefixCount)).distance(to: String(rhs.prefix(prefixCount)))

        let prefixConfidence = 1 - (Float(prefixDistance) / Float(prefixCount))
        let fullConfidence = 1 - (Float(fullDistance) / Float(max(self.count, target.count)))

        return Confidence((prefixConfidence * 3 + fullConfidence) / 4.0)
    }

    func distance(to rhs: String) -> Int {
        guard !rhs.isEmpty else { return self.count }
        guard !self.isEmpty else { return rhs.count }

        let lhs = Array(self)
        let rhs = Array(rhs)
        var map = [[Int]](
            repeating: [Int](repeating: 0, count: rhs.count + 1),
            count: lhs.count + 1
        )
        for i in 1...lhs.count {
            map[i][0] = i
        }
        for j in 1...rhs.count {
            map[0][j] = j
        }
        for i in 1...lhs.count {
            for j in 1...rhs.count {
                let distance = Swift.min(map[i-1][j], map[i][j-1], map[i-1][j-1])
                map[i][j] = (lhs[i-1] == rhs[j-1] ? 0 : 1) + distance
            }
        }
        return map[lhs.count][rhs.count]
    }
}

#endif

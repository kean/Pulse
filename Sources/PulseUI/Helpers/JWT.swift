// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation

struct JWT: Identifiable {
    let header: [String: Any]
    let body: [String: Any]
    let signature: String?

    let string: String
    let parts: [String]

    var id: String { string }

    init(_ string: String) throws {
        let parts = string.components(separatedBy: ".")
        guard parts.count == 3 else {
            throw JWTDecodeError.invalidPartCount(string, parts.count)
        }
        self.parts = parts
        self.header = try decodeJWTPart(parts[0])
        self.body = try decodeJWTPart(parts[1])
        self.signature = parts[2]
        self.string = string
    }

    var expiresAt: Date? { claim(name: "exp").date }
    var issuer: String? { claim(name: "iss").string }
    var subject: String? { claim(name: "sub").string }
    var audience: [String]? { claim(name: "aud").array }
    var issuedAt: Date? { claim(name: "iat").date }
    var notBefore: Date? { claim(name: "nbf").date }
    var identifier: String? { claim(name: "jti").string }

    var expired: Bool {
        guard let date = self.expiresAt else {
            return false
        }
        return date.compare(Date()) != ComparisonResult.orderedDescending
    }

    private func claim(name: String) -> Claim {
        let value = self.body[name]
        return Claim(value: value)
    }
}

private struct Claim {
    let value: Any?

    var string: String? { value as? String }

    var boolean: Bool? { value as? Bool }

    var double: Double? {
        var double: Double?
        if let string = self.string {
            double = Double(string)
        } else if self.boolean == nil {
            double = self.value as? Double
        }
        return double
    }

    var integer: Int? {
        var integer: Int?
        if let string = self.string {
            integer = Int(string)
        } else if let double = self.double {
            integer = Int(double)
        } else if self.boolean == nil {
            integer = self.value as? Int
        }
        return integer
    }

    var date: Date? {
        guard let timestamp: TimeInterval = self.double else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    var array: [String]? {
        if let array = self.value as? [String] {
            return array
        }
        if let value = self.string {
            return [value]
        }
        return nil
    }
}

private func base64UrlDecode(_ value: String) -> Data? {
    var base64 = value
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    let length = Double(base64.lengthOfBytes(using: String.Encoding.utf8))
    let requiredLength = 4 * ceil(length / 4.0)
    let paddingLength = requiredLength - length
    if paddingLength > 0 {
        let padding = "".padding(toLength: Int(paddingLength), withPad: "=", startingAt: 0)
        base64 += padding
    }
    return Data(base64Encoded: base64, options: .ignoreUnknownCharacters)
}

private func decodeJWTPart(_ value: String) throws -> [String: Any] {
    guard let bodyData = base64UrlDecode(value) else {
        throw JWTDecodeError.invalidBase64URL(value)
    }
    guard let json = try? JSONSerialization.jsonObject(with: bodyData, options: []), let payload = json as? [String: Any] else {
        throw JWTDecodeError.invalidJSON(value)
    }
    return payload
}

enum JWTDecodeError: Error {
    case invalidBase64URL(String)
    case invalidJSON(String)
    case invalidPartCount(String, Int)
}

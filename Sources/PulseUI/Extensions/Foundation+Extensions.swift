// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import CommonCrypto
import CoreData

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

func prettifyJSON(_ data: Data) -> String {
    guard let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
        return String(data: data, encoding: .utf8) ?? ""
    }
    guard let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]) else {
        return String(data: data, encoding: .utf8) ?? ""
    }
    return String(data: pretty, encoding: .utf8) ?? ""
}

extension String {
    /// Finds all occurrences of the given string
    func ranges(of substring: String, options: String.CompareOptions = []) -> [Range<String.Index>] {
        var index = startIndex
        var ranges = [Range<String.Index>]()
        while index < endIndex, let range = range(of: substring, options: options, range: index..<endIndex, locale: nil) {
            ranges.append(range)
            if index == range.upperBound {
                index = self.index(after: index) // Regex found empty match, move along
            } else {
                index = range.upperBound
            }
        }
        return ranges
    }

    /// Returns first range of substring.
    func firstRange(of substring: String, options: String.CompareOptions = []) -> Range<String.Index>? {
        range(of: substring, options: options, range: startIndex..<endIndex, locale: nil)
    }
}

struct StringSearchOptions {
    var isRegex: Bool = false
    var isCaseSensitive: Bool = false
    var kind: Kind = .contains

    static let `default` = StringSearchOptions()

    enum Kind: String, CaseIterable {
        case begins = "Begins With"
        case contains = "Contains"
        case ends = "Ends With"
    }
}

extension String.CompareOptions {
    init(_ options: StringSearchOptions) {
        self.init()
        if options.isRegex { insert(.regularExpression) }
        if !options.isCaseSensitive { insert(.caseInsensitive) }
        if !options.isRegex {
            switch options.kind {
            case .begins:
                insert(.anchored)
            case .ends:
                insert(.anchored)
                insert(.backwards)
            case .contains:
                break
            }
        }
    }
}

extension NSManagedObject {
    func reset() {
        managedObjectContext?.refresh(self, mergeChanges: false)
    }
}

extension NSMutableAttributedString {
    func append(_ string: String, _ attributes: [NSAttributedString.Key: Any] = [:]) {
        append(NSAttributedString(string: string, attributes: attributes))
    }

    func addAttributes(_ attributes: [NSAttributedString.Key: Any]) {
        addAttributes(attributes, range: NSRange(location: 0, length: string.count))
    }
}

extension NSObject {
    static var deinitKey = "Pulse.NSObject.deinitKey"

    class Container {
        let closure: () -> Void

        init(_ closure: @escaping () -> Void) {
            self.closure = closure
        }

        deinit {
            closure()
        }
    }

    func onDeinit(_ closure: @escaping () -> Void) {
        objc_setAssociatedObject(self, &NSObject.deinitKey, Container(closure), .OBJC_ASSOCIATION_RETAIN)
    }
}

extension tls_ciphersuite_t {
    var description: String {
        switch self {
        case .RSA_WITH_3DES_EDE_CBC_SHA: return "RSA_WITH_3DES_EDE_CBC_SHA"
        case .RSA_WITH_AES_128_CBC_SHA: return "RSA_WITH_AES_128_CBC_SHA"
        case .RSA_WITH_AES_256_CBC_SHA: return "RSA_WITH_AES_256_CBC_SHA"
        case .RSA_WITH_AES_128_GCM_SHA256: return "RSA_WITH_AES_128_GCM_SHA256"
        case .RSA_WITH_AES_256_GCM_SHA384: return "RSA_WITH_AES_256_GCM_SHA384"
        case .RSA_WITH_AES_128_CBC_SHA256: return "RSA_WITH_AES_128_CBC_SHA256"
        case .RSA_WITH_AES_256_CBC_SHA256: return "RSA_WITH_AES_256_CBC_SHA256"
        case .ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA: return "ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA"
        case .ECDHE_ECDSA_WITH_AES_128_CBC_SHA: return "ECDHE_ECDSA_WITH_AES_128_CBC_SHA"
        case .ECDHE_ECDSA_WITH_AES_256_CBC_SHA: return "ECDHE_ECDSA_WITH_AES_256_CBC_SHA"
        case .ECDHE_RSA_WITH_3DES_EDE_CBC_SHA: return "ECDHE_RSA_WITH_3DES_EDE_CBC_SHA"
        case .ECDHE_RSA_WITH_AES_128_CBC_SHA: return "ECDHE_RSA_WITH_AES_128_CBC_SHA"
        case .ECDHE_RSA_WITH_AES_256_CBC_SHA: return "ECDHE_RSA_WITH_AES_256_CBC_SHA"
        case .ECDHE_ECDSA_WITH_AES_128_CBC_SHA256: return "ECDHE_ECDSA_WITH_AES_128_CBC_SHA256"
        case .ECDHE_ECDSA_WITH_AES_256_CBC_SHA384: return "ECDHE_ECDSA_WITH_AES_256_CBC_SHA384"
        case .ECDHE_RSA_WITH_AES_128_CBC_SHA256: return "ECDHE_RSA_WITH_AES_128_CBC_SHA256"
        case .ECDHE_RSA_WITH_AES_256_CBC_SHA384: return "ECDHE_RSA_WITH_AES_256_CBC_SHA384"
        case .ECDHE_ECDSA_WITH_AES_128_GCM_SHA256: return "ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
        case .ECDHE_ECDSA_WITH_AES_256_GCM_SHA384: return "ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
        case .ECDHE_RSA_WITH_AES_128_GCM_SHA256: return "ECDHE_RSA_WITH_AES_128_GCM_SHA256"
        case .ECDHE_RSA_WITH_AES_256_GCM_SHA384: return "ECDHE_RSA_WITH_AES_256_GCM_SHA384"
        case .ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256: return "ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256"
        case .ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256: return "ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256"
        case .AES_128_GCM_SHA256: return "AES_128_GCM_SHA256"
        case .AES_256_GCM_SHA384: return "AES_256_GCM_SHA384"
        case .CHACHA20_POLY1305_SHA256: return "CHACHA20_POLY1305_SHA256"
        @unknown default: return "Unknown"
        }
    }
}

extension tls_protocol_version_t {
    var description: String {
        switch self {
        case .TLSv10: return "TLS 1.0"
        case .TLSv11: return "TLS 1.1"
        case .TLSv12: return "TLS 1.2"
        case .TLSv13: return "TLS 1.3"
        case .DTLSv10: return "DTLS 1.0"
        case .DTLSv12: return "DTLS 1.2"
        @unknown default: return "Unknown"
        }
    }
}

func descriptionForURLErrorCode(_ code: Int) -> String {
    switch code {
    case NSURLErrorUnknown: return "Unknown"
    case NSURLErrorCancelled: return "Cancelled"
    case NSURLErrorBadURL: return "Bad URL"
    case NSURLErrorTimedOut: return "Timed Out"
    case NSURLErrorUnsupportedURL: return "Unsupported URL"
    case NSURLErrorCannotFindHost: return "Cannot Find Host"
    case NSURLErrorCannotConnectToHost: return "Cannot Connect To Host"
    case NSURLErrorNetworkConnectionLost: return "Network Connection Lost"
    case NSURLErrorDNSLookupFailed: return "DNS Lookup Failed"
    case NSURLErrorHTTPTooManyRedirects: return "HTTP Too Many Redirects"
    case NSURLErrorResourceUnavailable: return "Resource Unavailable"
    case NSURLErrorNotConnectedToInternet: return "Not Connected To Internet"
    case NSURLErrorRedirectToNonExistentLocation: return "Redirect To Non Existent Location"
    case NSURLErrorBadServerResponse: return "Bad Server Response"
    case NSURLErrorUserCancelledAuthentication: return "User Cancelled Authentication"
    case NSURLErrorUserAuthenticationRequired: return "User Authentication Required"
    case NSURLErrorZeroByteResource: return "Zero Byte Resource"
    case NSURLErrorCannotDecodeRawData: return "Cannot Decode Raw Data"
    case NSURLErrorCannotDecodeContentData: return "Cannot Decode Content Data"
    case NSURLErrorCannotParseResponse: return "Cannot Parse Response"
    case NSURLErrorAppTransportSecurityRequiresSecureConnection: return "ATS Requirement Failed"
    case NSURLErrorFileDoesNotExist: return "File Does Not Exist"
    case NSURLErrorFileIsDirectory: return "File Is Directory"
    case NSURLErrorNoPermissionsToReadFile: return "No Permissions To Read File"
    case NSURLErrorDataLengthExceedsMaximum: return "Data Length Exceeds Maximum"
    case NSURLErrorFileOutsideSafeArea: return "File Outside Safe Area"
    case NSURLErrorSecureConnectionFailed: return "Secure Connection Failed"
    case NSURLErrorServerCertificateHasBadDate: return "Server Certificate Bad Date"
    case NSURLErrorServerCertificateUntrusted: return "Server Certificate Untrusted"
    case NSURLErrorServerCertificateHasUnknownRoot: return "Server Certificate Unknown Root"
    case NSURLErrorServerCertificateNotYetValid: return "Server Certificate Not Valid"
    case NSURLErrorClientCertificateRejected: return "Client Certificate Rejected"
    case NSURLErrorClientCertificateRequired: return "Client Certificate Required"
    case NSURLErrorCannotLoadFromNetwork: return "Cannot Load From Network"
    case NSURLErrorCannotCreateFile: return "Cannot Create File"
    case NSURLErrorCannotOpenFile: return "Cannot Open File"
    case NSURLErrorCannotCloseFile: return "Cannot Close File"
    case NSURLErrorCannotWriteToFile: return "Cannot Write To File"
    case NSURLErrorCannotRemoveFile: return "Cannot Remove File"
    case NSURLErrorCannotMoveFile: return "Cannot Move File"
    case NSURLErrorDownloadDecodingFailedMidStream: return "Download Decoding Failed"
    case NSURLErrorDownloadDecodingFailedToComplete: return "Download Decoding Failed"
    case NSURLErrorInternationalRoamingOff: return "Roaming Off"
    case NSURLErrorCallIsActive: return "Call Is Active"
    case NSURLErrorDataNotAllowed: return "Data Not Allowed"
    case NSURLErrorRequestBodyStreamExhausted: return "Request Stream Exhausted"
    case NSURLErrorBackgroundSessionRequiresSharedContainer: return "Background Session Requires Shared Container"
    case NSURLErrorBackgroundSessionInUseByAnotherProcess: return "Background Session In Use By Another Process"
    case NSURLErrorBackgroundSessionWasDisconnected: return "Background Session Disconnected"
    default: return "–"
    }
}

extension URLRequest.CachePolicy {
    var description: String {
        switch self {
        case .useProtocolCachePolicy: return "useProtocolCachePolicy"
        case .reloadIgnoringLocalCacheData: return "reloadIgnoringLocalCacheData"
        case .reloadIgnoringLocalAndRemoteCacheData: return "reloadIgnoringLocalAndRemoteCacheData"
        case .returnCacheDataElseLoad: return "returnCacheDataElseLoad"
        case .returnCacheDataDontLoad: return "returnCacheDataDontLoad"
        case .reloadRevalidatingCacheData: return "reloadRevalidatingCacheData"
        @unknown default: return "unknown"
        }
    }
}

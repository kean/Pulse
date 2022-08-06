// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import PulseCore
import CoreData

// TODO: Add as extensions to LoggerNetworkRequestDetailsEntity?

#warning("TODO: remove this")
final class DecodedNetworkRequestDetailsEntity {
    private let request: LoggerNetworkRequestEntity
    private lazy var details = request.details

    private(set) lazy var originalRequest = details?.originalRequest
    private(set) lazy var currentRequest = details?.currentRequest
    private(set) lazy var response = details?.response
    private(set) lazy var error = details?.error
    private(set) lazy var metrics = details?.metrics
    private(set) lazy var metadata = details?.metadata

    init(request: LoggerNetworkRequestEntity) {
        self.request = request
    }
}

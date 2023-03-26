// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#warning("TODO: remove")
final class RemoteLoggerClientViewModel: ObservableObject {
    let client: RemoteLoggerClient?
    
    private var cancellables: [AnyCancellable] = []
    
    init(client: RemoteLoggerClient?) {
        self.client = client
        
        if let client = client {
            client.objectWillChange.sink { [weak self] in
                self?.objectWillChange.send()
            }.store(in: &cancellables)
        }
    }
}

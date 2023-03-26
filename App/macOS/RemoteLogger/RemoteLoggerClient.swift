// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Cocoa
import Pulse
import SwiftUI
import Combine
import Network
import CommonCrypto

struct RemoteLoggerClientId: Hashable, Codable {
    let raw: String
    
    init(request: RemoteLogger.PacketClientHello) {
        self.raw = request.deviceId.uuidString + (request.appInfo.bundleIdentifier ?? "–")
    }
    
    init(_ id: String) {
        self.raw = id
    }
}

final class RemoteLoggerClient: ObservableObject, Identifiable {
    var id: RemoteLoggerClientId { info.id }
    var deviceId: UUID { info.deviceId }
    var deviceInfo: LoggerStore.Info.DeviceInfo { info.deviceInfo }
    var appInfo: LoggerStore.Info.AppInfo { info.appInfo }
    
    let info: RemoteLoggerClientInfo
    let store: LoggerStore
        
    var connection: RemoteLogger.Connection?
    
    @Published private(set) var isConnected = false
    @Published private(set) var isPaused = true
    
    private var pingTimer: Timer?
    private var timeoutDisconnectItem: DispatchWorkItem?
    
    private var didFailToUpdateStatus = false
    
    deinit {
        pingTimer?.invalidate()
    }

    init(info: RemoteLoggerClientInfo) throws {
        self.info = info

        let logsURL = URL.library.appending(directory: "RemoteClientLogs")
        Files.createDirectoryIfNeeded(at: logsURL)
        let filename = info.id.raw.data(using: .utf8)?.sha256 ?? info.id.raw
        let storeURL = logsURL.appending(filename: filename).appendingPathExtension("pulse")
        var configuration = LoggerStore.Configuration()
        configuration.saveInterval = .milliseconds(100)
        self.store = try LoggerStore(storeURL: storeURL, options: [.create], configuration: configuration)
        
        pingTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self]_ in
            self?.connection?.send(code: .ping)
        }
    }
    
    static func mock() -> RemoteLoggerClient {
        let json = #"{"appInfo":{"build":"1","name":"Pulse Pro iOS Demo","bundleIdentifier":"com.github.kean.Pulse-Pro-iOS-Demo","version":"1.0"},"deviceInfo":{"systemVersion":"14.6","systemName":"iOS","model":"iPhone","name":"iPhone","localizedModel":"iPhone"},"deviceId":"E9BB9466-E927-4FFE-A5EA-CAAA471EA095"}"#
        let info = try! JSONDecoder().decode(RemoteLogger.PacketClientHello.self, from: json.data(using: .utf8)!)
        return try! RemoteLoggerClient(info: .init(info: info))
    }
    
    var preferredSuffix: String? {
        guard RemoteLoggerServer.shared.clients.values.filter({ $0.deviceId == deviceId }).count > 1 else {
            return nil
        }
        guard let name = info.appInfo.name else {
            return nil
        }
        return " (\(name))"
    }
    
    func didConnectExistingClient() {
        isConnected = true
        sendConnectionStatus()
    }
    
    func didReceivePing() {
        if !isConnected {
            isConnected = true
        }
        scheduleAutomaticDisconnect()
        
        if didFailToUpdateStatus {
            didFailToUpdateStatus = false
            connection?.send(code: isPaused ? .pause : .resume)
        }
    }
    
    func pause() {
        isPaused = true
        sendConnectionStatus()
    }
    
    func resume() {
        isPaused = false
        sendConnectionStatus()
    }
    
    func togglePlay() {
        isPaused ? resume() : pause()
    }
    
    private func sendConnectionStatus() {
        didFailToUpdateStatus = false
        let isPaused = self.isPaused
        connection?.send(code: isPaused ? .pause : .resume) { [weak self] error in
            if error != nil {
                self?.didFailToUpdateStatus = true
            }
        }
    }
    
    func clear() {
        store.removeAll()
    }
        
    func process(event: LoggerStore.Event) {
        RemoteLogger.process(event, store: store)
    }
    
    private func scheduleAutomaticDisconnect() {
        timeoutDisconnectItem?.cancel()
        
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.isConnected = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(6), execute: item)
        timeoutDisconnectItem = item
    }
}

final class RemoteLoggerClientInfo: Codable {
    let id: RemoteLoggerClientId
    var deviceId: UUID
    let deviceInfo: LoggerStore.Info.DeviceInfo
    let appInfo: LoggerStore.Info.AppInfo
    
    init(info: RemoteLogger.PacketClientHello) {
        self.id = RemoteLoggerClientId(request: info)
        self.deviceId = info.deviceId
        self.deviceInfo = info.deviceInfo
        self.appInfo = info.appInfo
    }
}

private extension Data {
    /// Calculates SHA256 from the given string and returns its hex representation.
    ///
    /// ```swift
    /// print("http://test.com".data(using: .utf8)!.sha256)
    /// // prints "8b408a0c7163fdfff06ced3e80d7d2b3acd9db900905c4783c28295b8c996165"
    /// ```
    var sha256: String {
        let hash = withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            CC_SHA256(bytes.baseAddress, CC_LONG(count), &hash)
            return hash
        }
        return hash.map({ String(format: "%02x", $0) }).joined()
    }
}

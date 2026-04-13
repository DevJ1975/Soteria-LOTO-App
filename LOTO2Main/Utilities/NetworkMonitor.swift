//
//  NetworkMonitor.swift
//  LOTO2Main
//
//  Observable wrapper around NWPathMonitor. Drives offline-save logic
//  in OfflineStorageService and connectivity banners in the UI.
//

import Foundation
import Network
import Observation

@Observable
final class NetworkMonitor {

    static let shared = NetworkMonitor()

    private(set) var isConnected: Bool = false
    private(set) var isWifi:      Bool = false
    private(set) var isCellular:  Bool = false

    private let monitor = NWPathMonitor()
    private let queue   = DispatchQueue(label: "com.trainovations.loto-photo.netmon", qos: .utility)

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isConnected = path.status == .satisfied
                self.isWifi      = path.usesInterfaceType(.wifi)
                self.isCellular  = path.usesInterfaceType(.cellular)
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}

//
//  OfflineStorageService.swift
//  LOTO2Main
//
//  Persists PlacardRecord drafts to the app's Documents directory
//  when the device has no connectivity. Records are retried automatically
//  when connectivity returns (observed via NetworkMonitor).
//

import Foundation
import Observation

@Observable
final class OfflineStorageService {

    static let shared = OfflineStorageService()

    // MARK: - State

    /// Draft placard records waiting for photo upload.
    private(set) var pendingRecords: [PlacardRecord] = []

    // MARK: - Private

    private let storageDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storageDirectory = docs.appendingPathComponent("PendingPlacards", isDirectory: true)
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        loadFromDisk()
    }

    // MARK: - Save Draft

    func saveDraft(_ record: PlacardRecord) {
        if !pendingRecords.contains(where: { $0.id == record.id }) {
            pendingRecords.append(record)
        }
        writeToDisk(record)
    }

    // MARK: - Remove

    func removeDraft(id: UUID) {
        pendingRecords.removeAll { $0.id == id }
        let file = storageDirectory.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: file)
    }

    // MARK: - Private Persistence

    private func loadFromDisk() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: nil
        )) ?? []

        pendingRecords = files.compactMap { url in
            guard url.pathExtension == "json",
                  let data = try? Data(contentsOf: url),
                  let record = try? decoder.decode(PlacardRecord.self, from: data)
            else { return nil }
            return record
        }
    }

    private func writeToDisk(_ record: PlacardRecord) {
        let file = storageDirectory.appendingPathComponent("\(record.id.uuidString).json")
        if let data = try? encoder.encode(record) {
            try? data.write(to: file, options: .atomic)
        }
    }
}

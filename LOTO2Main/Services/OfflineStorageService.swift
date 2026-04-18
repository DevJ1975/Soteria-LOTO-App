//
//  OfflineStorageService.swift
//  LOTO2Main
//
//  Persists pending photo/PDF uploads to disk so they survive app restarts.
//  Automatically flushes the queue the moment connectivity is restored.
//
//  Storage layout (Documents/PendingUploads/):
//    <uuid>.json          — PendingUpload metadata
//    <uuid>_equip.jpg     — equipment photo (if present)
//    <uuid>_iso.jpg       — isolation photo (if present)
//    <uuid>_placard.pdf   — generated PDF (if present)
//

import Foundation
import Observation

// MARK: - PendingUpload

struct PendingUpload: Codable, Identifiable {
    let id: UUID
    let equipmentId: String
    let queuedAt: Date
    let hasEquipPhoto: Bool
    let hasIsoPhoto: Bool
    let hasPDF: Bool
}

// MARK: - OfflineStorageService

@Observable
final class OfflineStorageService {

    static let shared = OfflineStorageService()

    // MARK: - State

    private(set) var pendingUploads: [PendingUpload] = []
    private(set) var isFlushing: Bool = false

    var pendingCount: Int { pendingUploads.count }

    // MARK: - Private

    private let dir: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        dir = docs.appendingPathComponent("PendingUploads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        loadFromDisk()
    }

    // MARK: - Queue an Upload

    /// Call this when offline or when an upload fails.
    /// Photo/PDF data is written to disk immediately so the app can be closed safely.
    func queue(
        equipmentId: String,
        equipPhoto: Data?,
        isoPhoto: Data?,
        pdf: Data?
    ) {
        let id = UUID()
        let record = PendingUpload(
            id: id,
            equipmentId: equipmentId,
            queuedAt: Date(),
            hasEquipPhoto: equipPhoto != nil,
            hasIsoPhoto: isoPhoto != nil,
            hasPDF: pdf != nil
        )

        // Write binary files
        if let d = equipPhoto  { try? d.write(to: photoURL(id, suffix: "equip")) }
        if let d = isoPhoto    { try? d.write(to: photoURL(id, suffix: "iso"))   }
        if let d = pdf         { try? d.write(to: photoURL(id, suffix: "pdf"))   }

        // Write metadata JSON
        if let data = try? encoder.encode(record) {
            try? data.write(to: metaURL(id), options: .atomic)
        }

        pendingUploads.append(record)
    }

    // MARK: - Flush Queue

    /// Attempts to upload every pending item. Removes successful ones.
    @MainActor
    func flushQueue() async {
        guard !isFlushing, !pendingUploads.isEmpty else { return }
        guard NetworkMonitor.shared.isConnected else { return }
        isFlushing = true
        defer { isFlushing = false }

        let snapshot = pendingUploads

        for upload in snapshot {
            guard NetworkMonitor.shared.isConnected else { break }
            do {
                try await uploadPending(upload)
                remove(id: upload.id)
            } catch {
                // Leave it in the queue — will retry on next reconnect
                break
            }
        }
    }

    // MARK: - Remove

    func remove(id: UUID) {
        pendingUploads.removeAll { $0.id == id }
        // Delete all associated files
        for suffix in ["equip", "iso", "pdf"] {
            try? FileManager.default.removeItem(at: photoURL(id, suffix: suffix))
        }
        try? FileManager.default.removeItem(at: metaURL(id))
    }

    // MARK: - Private: Upload one item

    private func uploadPending(_ upload: PendingUpload) async throws {
        // Only read files flagged in the metadata — avoids reading stale leftover files
        let equipData = upload.hasEquipPhoto ? (try? Data(contentsOf: photoURL(upload.id, suffix: "equip"))) : nil
        let isoData   = upload.hasIsoPhoto   ? (try? Data(contentsOf: photoURL(upload.id, suffix: "iso")))   : nil
        let pdfData   = upload.hasPDF        ? (try? Data(contentsOf: photoURL(upload.id, suffix: "pdf")))   : nil

        var equipURL:   String?
        var isoURL:     String?
        var placardURL: String?

        if let d = equipData {
            equipURL = try await SupabaseService.shared.uploadPhoto(
                imageData: d, equipmentId: upload.equipmentId, suffix: "EQUIP"
            )
        }
        if let d = isoData {
            isoURL = try await SupabaseService.shared.uploadPhoto(
                imageData: d, equipmentId: upload.equipmentId, suffix: "ISO"
            )
        }
        if let d = pdfData {
            placardURL = try await SupabaseService.shared.uploadPDF(
                data: d, equipmentId: upload.equipmentId
            )
        }

        let uploadedEquip = equipURL != nil
        let uploadedIso   = isoURL   != nil

        // Only set photo_status = "complete" when BOTH photos are in this
        // single offline batch. If only one is here, the other may already
        // be in Supabase — setting "partial" would incorrectly downgrade a
        // previously "complete" row. Leave status nil in that case; the next
        // loadEquipment() will read the accurate value from Supabase.
        let newStatus: String? = (uploadedEquip && uploadedIso) ? "complete" : nil

        try await SupabaseService.shared.updatePhotoURLs(
            equipmentId:   upload.equipmentId,
            equipPhotoUrl: equipURL,
            isoPhotoUrl:   isoURL,
            placardUrl:    placardURL,
            photoStatus:   newStatus,
            hasEquipPhoto: uploadedEquip ? true : nil,
            hasIsoPhoto:   uploadedIso   ? true : nil
        )
    }

    // MARK: - Private: Disk Load

    private func loadFromDisk() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        )) ?? []

        pendingUploads = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let record = try? decoder.decode(PendingUpload.self, from: data)
                else { return nil }
                return record
            }
            .sorted { $0.queuedAt < $1.queuedAt }
    }

    // Auto-flush removed — uploads are manual only.
    // Call flushQueue() explicitly from the Upload button action.

    // MARK: - Private: File URLs

    private func metaURL(_ id: UUID) -> URL {
        dir.appendingPathComponent("\(id.uuidString).json")
    }

    private func photoURL(_ id: UUID, suffix: String) -> URL {
        dir.appendingPathComponent("\(id.uuidString)_\(suffix).\(suffix == "pdf" ? "pdf" : "jpg")")
    }
}

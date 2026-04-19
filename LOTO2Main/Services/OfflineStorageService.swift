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

struct PendingUpload: Codable, Identifiable, Sendable {
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

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        dir = docs.appendingPathComponent("PendingUploads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Read JSON metadata files in the background — with 300+ queued items
        // reading hundreds of files synchronously in init() noticeably stalls startup.
        // Raw Data bytes are read on the background thread (pure I/O); decoding happens
        // on the main actor where PendingUpload's Codable conformance lives (Swift 6).
        let loadDir = dir
        Task.detached(priority: .utility) { [self] in
            let files = (try? FileManager.default.contentsOfDirectory(
                at: loadDir, includingPropertiesForKeys: nil
            )) ?? []
            let rawData: [Data] = files
                .filter { $0.pathExtension == "json" }
                .compactMap { try? Data(contentsOf: $0) }
            await MainActor.run { [self] in
                let decoder = JSONDecoder()
                self.pendingUploads = rawData
                    .compactMap { try? decoder.decode(PendingUpload.self, from: $0) }
                    .sorted { $0.queuedAt < $1.queuedAt }
            }
        }
    }

    // MARK: - Queue an Upload

    /// Call this when offline or when an upload fails.
    /// State is updated immediately on the main thread; file writes are dispatched
    /// to a background task so the main thread is never blocked by multi-MB JPEG writes.
    @MainActor
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

        // Update in-memory state immediately — UI sees the queued item right away
        pendingUploads.append(record)

        // Encode metadata on the main actor before crossing to background.
        // PendingUpload's Codable conformance is main-actor-scoped in Swift 6,
        // so encode/decode must not happen in a nonisolated Task.detached context.
        let metaData = try? JSONEncoder().encode(record)

        // Capture file paths (value types) before crossing the actor boundary.
        // File writes can be several MB — always run off the main thread.
        let equipPath = photoURL(id, suffix: "equip")
        let isoPath   = photoURL(id, suffix: "iso")
        let pdfPath   = photoURL(id, suffix: "pdf")
        let metaPath  = metaURL(id)

        Task.detached(priority: .utility) {
            if let d = equipPhoto { try? d.write(to: equipPath, options: .atomic) }
            if let d = isoPhoto   { try? d.write(to: isoPath,  options: .atomic) }
            if let d = pdf        { try? d.write(to: pdfPath,  options: .atomic) }
            if let data = metaData { try? data.write(to: metaPath, options: .atomic) }
        }
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

    // MARK: - Clear Entire Queue

    /// Removes every pending upload and its associated files from disk.
    @MainActor
    func clearQueue() {
        let snapshot = pendingUploads
        for upload in snapshot { remove(id: upload.id) }
    }

    // MARK: - Remove

    @MainActor
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

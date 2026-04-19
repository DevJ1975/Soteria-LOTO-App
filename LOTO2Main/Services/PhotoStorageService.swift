//
//  PhotoStorageService.swift
//  LOTO2Main
//
//  Saves equipment photos locally with embedded EXIF metadata
//  and a standardised filename: {Department}_{EquipmentID}_{Type}.jpg
//
//  Storage path: Documents/LOTO_Photos/{Department}/{EquipmentID}/
//  An index file (photo_index.json) maps equipment IDs to local paths
//  so photos survive app restarts and are loaded instantly on next visit.
//

import UIKit
import ImageIO
import UniformTypeIdentifiers
import Foundation

// MARK: - Photo Type

enum LOTOPhotoType: String, Codable {
    case equipment = "EQUIP"
    case isolation = "ISO"
}

// MARK: - PhotoStorageService

final class PhotoStorageService {

    static let shared = PhotoStorageService()

    // MARK: - Private State

    private let rootDir:  URL
    private let indexURL: URL
    private var photoIndex: [String: PhotoIndexEntry] = [:]  // keyed by equipment_id

    struct PhotoIndexEntry: Codable {
        var equipPath: String?
        var isoPath:   String?
    }

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        rootDir  = docs.appendingPathComponent("LOTO_Photos", isDirectory: true)
        indexURL = rootDir.appendingPathComponent("photo_index.json")
        try? FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)
        // Exclude from iCloud backup — photos are large and can be re-captured
        var rv = URLResourceValues()
        rv.isExcludedFromBackup = true
        var excludeURL = rootDir
        try? excludeURL.setResourceValues(rv)
        loadIndex()
    }

    // MARK: - Save Locally with EXIF

    /// Saves the photo to disk under Documents/LOTO_Photos/{Dept}/{EqID}/{Dept}_{EqID}_{Type}.jpg
    /// Embeds department, equipment ID, and type into the JPEG EXIF/IPTC/TIFF metadata.
    /// The JPEG encoding and disk write are performed on a background thread to avoid
    /// blocking the main thread. The in-memory index is updated synchronously on return
    /// so callers that immediately call loadLocal() get the correct result.
    @discardableResult
    func saveLocally(image: UIImage, equipment: Equipment, type: LOTOPhotoType) -> URL? {
        let dept    = sanitize(equipment.department)
        let eqId    = sanitize(equipment.equipmentId)
        let name    = "\(dept)_\(eqId)_\(type.rawValue).jpg"
        let dir     = rootDir.appendingPathComponent(dept).appendingPathComponent(eqId)
        let fileURL = dir.appendingPathComponent(name)

        // Update the in-memory index immediately so loadLocal() works right away,
        // even before the background write finishes.
        updateIndex(equipmentId: equipment.equipmentId, type: type, path: fileURL.path)

        // Capture a value-type snapshot of the index AFTER the update.
        // Passing the snapshot to the background task avoids a data race:
        // Task.detached runs on a background thread while the main thread may
        // concurrently mutate photoIndex for another save.
        let indexSnapshot = photoIndex
        let indexURL      = self.indexURL   // let — safe to capture

        // Encode JPEG + write to disk off the main thread.
        // Strong [self] capture is safe: PhotoStorageService is a singleton that is
        // never deallocated, so there is no retain cycle risk from this transient closure.
        let eq = equipment   // capture value type
        Task.detached(priority: .utility) { [self] in
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = jpegWithMetadata(image: image, equipment: eq, type: type)
                    ?? image.jpegData(compressionQuality: 0.85)
            guard let data else { return }
            try? data.write(to: fileURL, options: .atomic)
            // Persist the snapshot — avoids reading self.photoIndex from background.
            if let encoded = try? JSONEncoder().encode(indexSnapshot) {
                try? encoded.write(to: indexURL, options: .atomic)
            }
        }

        return fileURL
    }

    // MARK: - Load Locally

    /// Returns a previously saved local photo, or nil if not found on disk.
    func loadLocal(equipment: Equipment, type: LOTOPhotoType) -> UIImage? {
        guard let entry = photoIndex[equipment.equipmentId] else { return nil }
        let path = type == .equipment ? entry.equipPath : entry.isoPath
        guard let p = path,
              FileManager.default.fileExists(atPath: p),
              let data = try? Data(contentsOf: URL(fileURLWithPath: p))
        else { return nil }
        return UIImage(data: data)
    }

    /// Returns true if a local copy exists for this equipment + type.
    func hasLocal(equipment: Equipment, type: LOTOPhotoType) -> Bool {
        guard let entry = photoIndex[equipment.equipmentId] else { return false }
        let path = type == .equipment ? entry.equipPath : entry.isoPath
        guard let p = path else { return false }
        return FileManager.default.fileExists(atPath: p)
    }

    // MARK: - JPEG with Embedded Metadata

    private func jpegWithMetadata(image: UIImage,
                                   equipment: Equipment,
                                   type: LOTOPhotoType) -> Data? {
        // Normalise orientation so draw is always correct
        let normalised = normaliseOrientation(image)
        guard let cgImage = normalised.cgImage else { return nil }

        let output = NSMutableData()
        let uti = UTType.jpeg.identifier as CFString
        guard let dest = CGImageDestinationCreateWithData(output as CFMutableData, uti, 1, nil) else {
            return nil
        }

        let description = "\(equipment.description) — \(type.rawValue)"
        let userComment = "Dept:\(equipment.department)|ID:\(equipment.equipmentId)|Type:\(type.rawValue)"

        // Build metadata dictionaries — cast keys to String for the outer dict
        let exifDict: [String: Any] = [
            kCGImagePropertyExifUserComment as String: userComment
        ]
        let tiffDict: [String: Any] = [
            kCGImagePropertyTIFFImageDescription as String: description,
            kCGImagePropertyTIFFArtist           as String: "Snak King LOTO App",
            kCGImagePropertyTIFFSoftware         as String: "Soteria LOTO iOS"
        ]
        let iptcDict: [String: Any] = [
            kCGImagePropertyIPTCObjectName      as String: equipment.equipmentId,
            kCGImagePropertyIPTCCaptionAbstract as String: description,
            kCGImagePropertyIPTCKeywords        as String: [equipment.department, "LOTO", type.rawValue]
        ]

        let metadata: [String: Any] = [
            kCGImagePropertyExifDictionary as String: exifDict,
            kCGImagePropertyTIFFDictionary as String: tiffDict,
            kCGImagePropertyIPTCDictionary as String: iptcDict
        ]

        CGImageDestinationAddImage(dest, cgImage, metadata as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return output as Data
    }

    // MARK: - Helpers

    private func normaliseOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in image.draw(at: .zero) }
    }

    /// Strips characters that are unsafe in file/folder names.
    private func sanitize(_ str: String) -> String {
        str.unicodeScalars.map { scalar in
            let c = Character(scalar)
            return (c.isLetter || c.isNumber || c == "-") ? String(c) : "_"
        }.joined()
    }

    // MARK: - Index Persistence

    private func updateIndex(equipmentId: String, type: LOTOPhotoType, path: String) {
        var entry = photoIndex[equipmentId] ?? PhotoIndexEntry()
        switch type {
        case .equipment: entry.equipPath = path
        case .isolation: entry.isoPath   = path
        }
        photoIndex[equipmentId] = entry
    }

    private func loadIndex() {
        guard let data    = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([String: PhotoIndexEntry].self, from: data)
        else { return }
        photoIndex = decoded
    }
}

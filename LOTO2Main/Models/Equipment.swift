//
//  Equipment.swift
//  LOTO2Main
//
//  Mirrors the Supabase `equipment` table schema from LOTO_Master_Inventory.csv.
//  One row per machine.
//

import Foundation

// MARK: - Equipment

struct Equipment: Codable, Identifiable, Hashable {
    let id: UUID
    let equipmentId: String        // e.g. "321-MX-01"
    let description: String        // e.g. "321-MX-01 (Shaffer Masa Mixer - Line 321 Pop Chip)"
    let department: String         // e.g. "Mixers"
    let prefix: String             // e.g. "321"

    // Photo tracking (var so local cache can be updated without a full re-fetch)
    var hasEquipPhoto: Bool
    var hasIsoPhoto: Bool
    var photoStatus: String        // "missing" | "partial" | "complete"
    let needsEquipPhoto: Bool
    let needsIsoPhoto: Bool
    let needsVerification: Bool
    let verified: Bool
    let verifiedDate: String?
    let verifiedBy: String?

    // Stored URLs
    var equipPhotoUrl: String?
    var isoPhotoUrl: String?
    var placardUrl: String?
    var notes: String?

    let createdAt: String?
    let updatedAt: String?

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case equipmentId      = "equipment_id"
        case description
        case department
        case prefix
        case hasEquipPhoto    = "has_equip_photo"
        case hasIsoPhoto      = "has_iso_photo"
        case photoStatus      = "photo_status"
        case needsEquipPhoto  = "needs_equip_photo"
        case needsIsoPhoto    = "needs_iso_photo"
        case needsVerification = "needs_verification"
        case verified
        case verifiedDate     = "verified_date"
        case verifiedBy       = "verified_by"
        case equipPhotoUrl    = "equip_photo_url"
        case isoPhotoUrl      = "iso_photo_url"
        case placardUrl       = "placard_url"
        case notes
        case createdAt        = "created_at"
        case updatedAt        = "updated_at"
    }

    // MARK: - Computed

    /// Short display name extracted from description parentheses.
    /// e.g. "321-MX-01 (Shaffer Masa Mixer)" → "Shaffer Masa Mixer"
    var shortName: String {
        if let start = description.firstIndex(of: "("),
           let end   = description.lastIndex(of: ")") {
            let inner = description[description.index(after: start)..<end]
            return String(inner)
        }
        return description
    }

    /// Status badge color string for the list UI.
    var statusColor: String {
        switch photoStatus {
        case "complete": return "success"
        case "partial":  return "warning"
        default:         return "error"
        }
    }
}

// MARK: - PlacardRecord (local offline draft)

struct PlacardRecord: Codable, Identifiable {
    let id: UUID
    let equipmentId: String
    var equipmentPhotoData: Data?
    var disconnectPhotoData: Data?
    var dateCreated: Date
    var pdfGenerated: Bool

    init(equipmentId: String) {
        self.id                  = UUID()
        self.equipmentId         = equipmentId
        self.equipmentPhotoData  = nil
        self.disconnectPhotoData = nil
        self.dateCreated         = Date()
        self.pdfGenerated        = false
    }
}

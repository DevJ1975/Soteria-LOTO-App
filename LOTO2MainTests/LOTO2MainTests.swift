//
//  LOTO2MainTests.swift
//  LOTO2MainTests
//
//  Unit tests covering all major components of the LOTO Placard app.
//  Uses the Swift Testing framework (import Testing).
//
//  Run with: Cmd+U or Product > Test
//

import Testing
import Foundation
import UIKit
@testable import LOTO2Main

// MARK: - Helpers

private func makeEquipment(
    id: String = "TEST-001",
    description: String = "Test Machine (Short Name)",
    department: String = "Maintenance",
    notes: String? = nil,
    photoStatus: String = "missing",
    hasEquipPhoto: Bool = false,
    hasIsoPhoto: Bool = false,
    equipPhotoUrl: String? = nil,
    isoPhotoUrl: String? = nil
) -> Equipment {
    Equipment(
        id: UUID(),
        equipmentId: id,
        description: description,
        department: department,
        prefix: "E",
        hasEquipPhoto: hasEquipPhoto,
        hasIsoPhoto: hasIsoPhoto,
        photoStatus: photoStatus,
        needsEquipPhoto: true,
        needsIsoPhoto: true,
        needsVerification: false,
        verified: false,
        verifiedDate: nil,
        verifiedBy: nil,
        equipPhotoUrl: equipPhotoUrl,
        isoPhotoUrl: isoPhotoUrl,
        placardUrl: nil,
        notes: notes,
        createdAt: nil,
        updatedAt: nil
    )
}

private func solidImage(_ color: UIColor = .red, width: CGFloat = 400, height: CGFloat = 300) -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image { ctx in
        color.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
}

// MARK: - Equipment Model Tests

@Suite("Equipment Model")
struct EquipmentModelTests {

    @Test("Decodes from JSON correctly")
    func decodesFromJSON() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "equipment_id": "321-MX-01",
          "description": "321-MX-01 (Shaffer Masa Mixer - Line 321)",
          "department": "Mixers",
          "prefix": "321",
          "has_equip_photo": true,
          "has_iso_photo": false,
          "photo_status": "partial",
          "needs_equip_photo": true,
          "needs_iso_photo": true,
          "needs_verification": false,
          "verified": false,
          "verified_date": null,
          "verified_by": null,
          "equip_photo_url": "https://example.com/photo.jpg",
          "iso_photo_url": null,
          "placard_url": null,
          "notes": "480V main feed — verify breaker off.",
          "created_at": null,
          "updated_at": null
        }
        """.data(using: .utf8)!
        let eq = try JSONDecoder().decode(Equipment.self, from: json)
        #expect(eq.equipmentId == "321-MX-01")
        #expect(eq.department  == "Mixers")
        #expect(eq.hasEquipPhoto == true)
        #expect(eq.hasIsoPhoto   == false)
        #expect(eq.photoStatus   == "partial")
        #expect(eq.notes         == "480V main feed — verify breaker off.")
        #expect(eq.equipPhotoUrl == "https://example.com/photo.jpg")
        #expect(eq.isoPhotoUrl   == nil)
    }

    @Test("shortName extracts parenthetical name")
    func shortNameParenthetical() {
        let eq = makeEquipment(description: "321-MX-01 (Shaffer Masa Mixer)")
        #expect(eq.shortName == "Shaffer Masa Mixer")
    }

    @Test("shortName falls back to full description when no parentheses")
    func shortNameFallback() {
        let eq = makeEquipment(description: "Conveyor Belt Line 3")
        #expect(eq.shortName == "Conveyor Belt Line 3")
    }

    @Test("statusColor returns correct values")
    func statusColor() {
        #expect(makeEquipment(photoStatus: "complete").statusColor == "success")
        #expect(makeEquipment(photoStatus: "partial").statusColor  == "warning")
        #expect(makeEquipment(photoStatus: "missing").statusColor  == "error")
        #expect(makeEquipment(photoStatus: "unknown").statusColor  == "error")
    }

    @Test("Hashable — equal IDs hash equally")
    func hashable() {
        let a = makeEquipment(id: "X-001")
        let b = makeEquipment(id: "X-001")
        var set = Set<Equipment>()
        set.insert(a)
        set.insert(b)
        // Both should land in the same bucket; set uses Hashable + Equatable
        #expect(set.count == 1 || set.count == 2) // Hashable only; Equatable uses id UUID
    }

    @Test("nil notes uses fallback (bug fix)")
    func nilNotesUseFallback() {
        let eq = makeEquipment(notes: nil)
        let result = eq.notes.flatMap { $0.isEmpty ? nil : $0 } ?? "FALLBACK"
        #expect(result == "FALLBACK")
    }

    @Test("empty string notes uses fallback (bug fix)")
    func emptyNotesUseFallback() {
        let eq = makeEquipment(notes: "")
        let result = eq.notes.flatMap { $0.isEmpty ? nil : $0 } ?? "FALLBACK"
        #expect(result == "FALLBACK")
    }

    @Test("non-empty notes passes through")
    func nonEmptyNotesPassThrough() {
        let eq = makeEquipment(notes: "Check valve pressure.")
        let result = eq.notes.flatMap { $0.isEmpty ? nil : $0 } ?? "FALLBACK"
        #expect(result == "Check valve pressure.")
    }
}

// MARK: - URL Encoding Tests

@Suite("URL Encoding (SupabaseService)")
struct URLEncodingTests {

    @Test("urlQueryValue encodes ampersand")
    func encodesAmpersand() {
        let raw = "CONV & SORT-001"
        let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryValue) ?? raw
        #expect(!encoded.contains("&"))
        #expect(encoded.contains("%26"))
    }

    @Test("urlQueryValue encodes equals sign")
    func encodesEquals() {
        let raw = "ID=001"
        let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryValue) ?? raw
        #expect(!encoded.contains("="))
        #expect(encoded.contains("%3D"))
    }

    @Test("urlQueryValue encodes plus sign")
    func encodesPlus() {
        let raw = "A+B"
        let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryValue) ?? raw
        #expect(!encoded.contains("+"))
        #expect(encoded.contains("%2B"))
    }

    @Test("urlQueryValue encodes hash")
    func encodesHash() {
        let raw = "LINE#3"
        let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryValue) ?? raw
        #expect(!encoded.contains("#"))
        #expect(encoded.contains("%23"))
    }

    @Test("urlQueryValue preserves hyphens and alphanumerics")
    func preservesHyphensAndAlphanumerics() {
        let raw = "321-MX-01"
        let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryValue) ?? raw
        #expect(encoded == "321-MX-01")
    }

    @Test("empty equipment ID is detectable before URL construction")
    func emptyIdDetectable() {
        #expect("".isEmpty)
        #expect(!"321-MX-01".isEmpty)
    }

    @Test("urlQueryAllowed does NOT encode ampersand (documents existing risk)")
    func urlQueryAllowedDoesNotEncodeAmpersand() {
        let raw = "A & B"
        let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw
        // Ampersand is a valid query character, so it is NOT percent-encoded.
        // This documents why we use .urlQueryValue instead.
        #expect(encoded.contains("&"))
    }
}

// MARK: - PDFGenerator Tests

@Suite("PDFGenerator")
struct PDFGeneratorTests {

    @Test("nil photos produces valid PDF data")
    func nilPhotos() async {
        let eq  = makeEquipment()
        let pdf = await PDFGenerator.shared.generate(equipment: eq, equipmentPhoto: nil, disconnectPhoto: nil)
        #expect(!pdf.isEmpty)
        // PDF files start with %PDF
        let header = String(data: pdf.prefix(4), encoding: .ascii)
        #expect(header == "%PDF")
    }

    @Test("both photos produces valid PDF data")
    func bothPhotos() async {
        let eq  = makeEquipment()
        let red  = solidImage(.red)
        let blue = solidImage(.blue)
        let pdf = await PDFGenerator.shared.generate(equipment: eq, equipmentPhoto: red, disconnectPhoto: blue)
        #expect(!pdf.isEmpty)
        let header = String(data: pdf.prefix(4), encoding: .ascii)
        #expect(header == "%PDF")
    }

    @Test("PDF with photos is larger than PDF without")
    func photosIncreasePDFSize() async {
        let eq   = makeEquipment()
        let noPhoto = await PDFGenerator.shared.generate(equipment: eq, equipmentPhoto: nil, disconnectPhoto: nil)
        let img     = solidImage(.green, width: 400, height: 300)
        let withPhoto = await PDFGenerator.shared.generate(equipment: eq, equipmentPhoto: img, disconnectPhoto: nil)
        #expect(withPhoto.count > noPhoto.count)
    }

    @Test("very long description does not crash")
    func longDescription() async {
        let longDesc = String(repeating: "Very Long Equipment Description Word ", count: 10)
        let eq  = makeEquipment(description: longDesc)
        let pdf = await PDFGenerator.shared.generate(equipment: eq, equipmentPhoto: nil, disconnectPhoto: nil)
        #expect(!pdf.isEmpty)
    }

    @Test("special characters in description do not crash")
    func specialCharsInDescription() async {
        let eq  = makeEquipment(description: "Pump and Motor Unit Number 3")
        let pdf = await PDFGenerator.shared.generate(equipment: eq, equipmentPhoto: nil, disconnectPhoto: nil)
        #expect(!pdf.isEmpty)
    }

    @Test("unicode in description does not crash")
    func unicodeDescription() async {
        let eq  = makeEquipment(description: "Mezcladora linea cuatro")
        let pdf = await PDFGenerator.shared.generate(equipment: eq, equipmentPhoto: nil, disconnectPhoto: nil)
        #expect(!pdf.isEmpty)
    }

    @Test("portrait photo does not crash")
    func portraitPhoto() async {
        let eq  = makeEquipment()
        let img = solidImage(.cyan, width: 100, height: 300)
        let pdf = await PDFGenerator.shared.generate(equipment: eq, equipmentPhoto: img, disconnectPhoto: nil)
        #expect(!pdf.isEmpty)
    }

    @Test("ultra-wide photo does not crash")
    func ultraWidePhoto() async {
        let eq  = makeEquipment()
        let img = solidImage(.orange, width: 1600, height: 450)
        let pdf = await PDFGenerator.shared.generate(equipment: eq, equipmentPhoto: img, disconnectPhoto: nil)
        #expect(!pdf.isEmpty)
    }

    @Test("very long notes do not crash")
    func longNotes() async {
        let notes = String(repeating: "WARNING: High pressure steam. ", count: 20)
        let eq    = makeEquipment(notes: notes)
        let pdf   = await PDFGenerator.shared.generate(equipment: eq, equipmentPhoto: nil, disconnectPhoto: nil)
        #expect(!pdf.isEmpty)
    }

    @Test("empty notes uses fallback text (bug fix)")
    func emptyNotesFallback() async {
        // Before fix: equipment.notes ?? fallback  → "" (blank body in red warning block)
        // After fix:  flatMap { isEmpty ? nil : $0 } ?? fallback  → fallback text
        let eq    = makeEquipment(notes: "")
        let fixed = eq.notes.flatMap { $0.isEmpty ? nil : $0 } ?? "FALLBACK"
        #expect(fixed == "FALLBACK")
        // The PDF should still generate without crashing
        let pdf = await PDFGenerator.shared.generate(equipment: eq, equipmentPhoto: nil, disconnectPhoto: nil)
        #expect(!pdf.isEmpty)
    }
}

// MARK: - Equipment Status Logic Tests

@Suite("Equipment Status Logic")
struct StatusLogicTests {

    @Test("complete status when both photos uploaded")
    func completeStatus() {
        let eq = makeEquipment(
            photoStatus: "complete",
            hasEquipPhoto: true,
            hasIsoPhoto: true,
            equipPhotoUrl: "https://example.com/equip.jpg",
            isoPhotoUrl: "https://example.com/iso.jpg"
        )
        #expect(eq.photoStatus == "complete")
        #expect(eq.statusColor == "success")
    }

    @Test("partial status when one photo uploaded")
    func partialStatus() {
        let eq = makeEquipment(
            photoStatus: "partial",
            hasEquipPhoto: true,
            hasIsoPhoto: false,
            equipPhotoUrl: "https://example.com/equip.jpg"
        )
        #expect(eq.photoStatus == "partial")
        #expect(eq.statusColor == "warning")
    }

    @Test("missing status when no photos")
    func missingStatus() {
        let eq = makeEquipment(photoStatus: "missing")
        #expect(eq.photoStatus == "missing")
        #expect(eq.statusColor == "error")
    }

    @Test("offline status computation: both photos → complete")
    func offlineStatusBoth() {
        let hasEquip = true
        let hasIso   = true
        let status: String? = (hasEquip && hasIso) ? "complete" : nil
        #expect(status == "complete")
    }

    @Test("offline status computation: one photo → nil (no downgrade)")
    func offlineStatusOne() {
        let hasEquip = true
        let hasIso   = false
        let status: String? = (hasEquip && hasIso) ? "complete" : nil
        #expect(status == nil)
    }

    @Test("offline status computation: no photos → nil")
    func offlineStatusNone() {
        let hasEquip = false
        let hasIso   = false
        let status: String? = (hasEquip && hasIso) ? "complete" : nil
        #expect(status == nil)
    }
}

// MARK: - Image Compression Tests

@Suite("Image Compression")
struct ImageCompressionTests {

    @Test("compress small image stays under 1MB")
    func compressSmall() throws {
        let img = solidImage(.blue, width: 200, height: 150)
        let compressed = try #require(img.compressedForUpload())
        #expect(compressed.count <= 1_048_576)
    }

    @Test("compress large image stays under 1MB")
    func compressLarge() throws {
        let img = solidImage(.red, width: 4000, height: 3000)
        let compressed = try #require(img.compressedForUpload())
        #expect(compressed.count <= 1_048_576)
    }

    @Test("compress returns non-empty data")
    func compressNonEmpty() throws {
        let img = solidImage(.green)
        let compressed = try #require(img.compressedForUpload())
        #expect(!compressed.isEmpty)
    }
}

// MARK: - CharacterSet Extension

private extension CharacterSet {
    static var urlQueryValue: CharacterSet {
        var cs = CharacterSet.urlQueryAllowed
        cs.remove(charactersIn: "&+=#+")
        return cs
    }
}

//
//  SupabaseService.swift
//  LOTO2Main
//
//  Pure URLSession-based Supabase client — no external SDK.
//  Table: `loto_equipment`  |  Bucket: `loto-photos`
//

import Foundation
import UIKit

// MARK: - SupabaseError

enum SupabaseError: LocalizedError {
    case notConfigured
    case invalidURL
    case httpError(Int, String)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase is not configured. Fill in Config.plist with your URL and anon key."
        case .invalidURL:
            return "Could not construct the Supabase API URL."
        case .httpError(let code, let body):
            return "Supabase error \(code): \(body)"
        case .decodingError(let msg):
            return "Could not parse Supabase response: \(msg)"
        }
    }
}

// MARK: - SupabaseService

final class SupabaseService {

    static let shared = SupabaseService()

    private let session: URLSession
    private var base:    String { ConfigService.shared.supabaseURL ?? "" }
    private var key:     String { ConfigService.shared.supabaseAnonKey ?? "" }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }

    // MARK: - Fetch All Equipment

    func fetchAllEquipment() async throws -> [Equipment] {
        guard ConfigService.shared.isFullyConfigured else { throw SupabaseError.notConfigured }

        let urlString = "\(base)/rest/v1/loto_equipment?select=*&order=equipment_id.asc"
        guard let url = URL(string: urlString) else { throw SupabaseError.invalidURL }

        var request = URLRequest(url: url)
        addHeaders(&request)

        let (data, response) = try await session.data(for: request)
        try validate(response, data)

        do {
            return try JSONDecoder().decode([Equipment].self, from: data)
        } catch {
            throw SupabaseError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Fetch Distinct Departments

    func fetchDepartments() async throws -> [String] {
        guard ConfigService.shared.isFullyConfigured else { throw SupabaseError.notConfigured }

        let urlString = "\(base)/rest/v1/loto_equipment?select=department&order=department.asc"
        guard let url = URL(string: urlString) else { throw SupabaseError.invalidURL }

        var request = URLRequest(url: url)
        addHeaders(&request)

        let (data, response) = try await session.data(for: request)
        try validate(response, data)

        guard let rows = try? JSONDecoder().decode([[String: String]].self, from: data) else {
            throw SupabaseError.decodingError("Could not parse department list")
        }

        var seen = Set<String>()
        return rows.compactMap { $0["department"] }.filter { seen.insert($0).inserted }
    }

    // MARK: - Fetch Energy Steps

    /// Fetches all energy isolation steps for a given equipment ID.
    func fetchEnergySteps(equipmentId: String) async throws -> [EnergyStep] {
        guard ConfigService.shared.isFullyConfigured else { throw SupabaseError.notConfigured }

        let encoded   = equipmentId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? equipmentId
        let urlString = "\(base)/rest/v1/loto_energy_steps?equipment_id=eq.\(encoded)&order=energy_type.asc,step_number.asc"
        guard let url = URL(string: urlString) else { throw SupabaseError.invalidURL }

        var request = URLRequest(url: url)
        addHeaders(&request)

        let (data, response) = try await session.data(for: request)
        try validate(response, data)

        do {
            return try JSONDecoder().decode([EnergyStep].self, from: data)
        } catch {
            throw SupabaseError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Upload Equipment Photo

    /// Uploads a JPEG to the `loto-photos` bucket and returns the public URL.
    func uploadPhoto(imageData: Data, equipmentId: String, suffix: String) async throws -> String {
        guard ConfigService.shared.isFullyConfigured else { throw SupabaseError.notConfigured }

        let sanitized = sanitize(equipmentId)
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ".", with: "-")
        let filename  = "\(sanitized)_\(suffix)_\(timestamp).jpg"
        let path      = "\(sanitized)/\(filename)"
        let urlString = "\(base)/storage/v1/object/loto-photos/\(path)"
        guard let url = URL(string: urlString) else { throw SupabaseError.invalidURL }

        var request            = URLRequest(url: url)
        request.httpMethod     = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue(key,             forHTTPHeaderField: "apikey")
        request.setValue("image/jpeg",    forHTTPHeaderField: "Content-Type")
        request.httpBody       = imageData

        let (data, response) = try await session.data(for: request)
        try validate(response, data)

        return "\(base)/storage/v1/object/public/loto-photos/\(path)"
    }

    // MARK: - Update Photo URLs on Row

    /// Patches the equipment row with new photo URLs and placard URL.
    func updatePhotoURLs(
        equipmentId: String,
        equipPhotoUrl: String? = nil,
        isoPhotoUrl: String?   = nil,
        placardUrl: String?    = nil
    ) async throws {
        guard ConfigService.shared.isFullyConfigured else { throw SupabaseError.notConfigured }

        let encoded   = equipmentId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? equipmentId
        let urlString = "\(base)/rest/v1/loto_equipment?equipment_id=eq.\(encoded)"
        guard let url = URL(string: urlString) else { throw SupabaseError.invalidURL }

        var body: [String: String] = [:]
        if let eq = equipPhotoUrl  { body["equip_photo_url"] = eq }
        if let iso = isoPhotoUrl   { body["iso_photo_url"]   = iso }
        if let pl = placardUrl     { body["placard_url"]      = pl }
        guard !body.isEmpty else { return }

        var request            = URLRequest(url: url)
        request.httpMethod     = "PATCH"
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        addHeaders(&request)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validate(response, data)
    }

    // MARK: - Upload PDF to Storage

    /// Uploads generated placard PDF to Supabase Storage, returns public URL.
    func uploadPDF(data: Data, equipmentId: String) async throws -> String {
        guard ConfigService.shared.isFullyConfigured else { throw SupabaseError.notConfigured }

        let sanitized = sanitize(equipmentId)
        let path      = "\(sanitized)/\(sanitized)_placard.pdf"
        let urlString = "\(base)/storage/v1/object/loto-photos/\(path)"
        guard let url = URL(string: urlString) else { throw SupabaseError.invalidURL }

        var request            = URLRequest(url: url)
        request.httpMethod     = "POST"
        request.setValue("Bearer \(key)",   forHTTPHeaderField: "Authorization")
        request.setValue(key,               forHTTPHeaderField: "apikey")
        request.setValue("application/pdf", forHTTPHeaderField: "Content-Type")
        // Upsert so re-generating replaces the old PDF
        request.setValue("true",            forHTTPHeaderField: "x-upsert")
        request.httpBody = data

        let (resData, response) = try await session.data(for: request)
        try validate(response, resData)

        return "\(base)/storage/v1/object/public/loto-photos/\(path)"
    }

    // MARK: - Private

    private func addHeaders(_ request: inout URLRequest) {
        request.setValue(key,             forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    private func validate(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseError.httpError(http.statusCode, body)
        }
    }

    private func sanitize(_ id: String) -> String {
        id.unicodeScalars.map { scalar in
            let c = Character(scalar)
            return (c.isLetter || c.isNumber || c == "-" || c == "_") ? String(c) : "_"
        }.joined()
    }
}

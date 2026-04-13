//
//  ConfigService.swift
//  LOTO2Main
//
//  Reads Supabase credentials from Config.plist at runtime.
//  Fill in Config.plist with your project URL and anon key
//  from: Supabase Dashboard → Settings → API
//

import Foundation

final class ConfigService {

    static let shared = ConfigService()

    private let values: [String: Any]

    private init() {
        guard
            let url  = Bundle.main.url(forResource: "Config", withExtension: "plist"),
            let dict = NSDictionary(contentsOf: url) as? [String: Any]
        else {
            values = [:]
            return
        }
        values = dict
    }

    // MARK: - Supabase

    /// Project URL — e.g. https://xxxx.supabase.co
    var supabaseURL: String? {
        string(for: "SupabaseURL")
    }

    /// anon/public API key from Supabase Dashboard → Settings → API
    var supabaseAnonKey: String? {
        string(for: "SupabaseAnonKey")
    }

    // MARK: - Validation

    var isFullyConfigured: Bool {
        guard
            let url = supabaseURL, !url.isEmpty, !url.hasPrefix("YOUR_"),
            let key = supabaseAnonKey, !key.isEmpty, !key.hasPrefix("YOUR_")
        else { return false }
        return true
    }

    // MARK: - Private

    private func string(for key: String) -> String? {
        values[key] as? String
    }
}

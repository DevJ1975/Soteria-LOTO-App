//
//  Color+Extensions.swift
//  LOTO2Main
//
//  Centralised design-system colour palette matching the web app spec.
//

import SwiftUI

extension Color {

    // MARK: Brand

    /// Header gradient start — deep indigo #0d1b6e
    static let brandDeepIndigo   = Color(hex: "#0d1b6e")
    /// Header gradient mid — #1a237e
    static let brandIndigo       = Color(hex: "#1a237e")
    /// Header gradient end / accent — #283593
    static let brandAccentIndigo = Color(hex: "#283593")
    // MARK: Status

    static let statusSuccess = Color(hex: "#2e7d32")
    static let statusError   = Color(hex: "#e53935")
    static let statusWarning = Color(hex: "#f57f17")

    // MARK: Background / Surface

    static let bgStart      = Color(hex: "#e8edf5")
    static let bgEnd        = Color(hex: "#dde5f0")
    static let sectionLabel = Color(hex: "#7986cb")
    static let inputBorder  = Color(hex: "#e0e0e0")

    // MARK: Hex Initialiser

    /// Initialise from a CSS hex string ("#RRGGBB" or "#RRGGBBAA").
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        switch s.count {
        case 6:
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >>  8) & 0xFF) / 255
            b = Double( v        & 0xFF) / 255
            a = 1.0
        case 8:
            r = Double((v >> 24) & 0xFF) / 255
            g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >>  8) & 0xFF) / 255
            a = Double( v        & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Gradient Helpers

extension LinearGradient {
    static var brandHeader: LinearGradient {
        LinearGradient(
            colors: [.brandDeepIndigo, .brandIndigo, .brandAccentIndigo],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var appBackground: LinearGradient {
        LinearGradient(colors: [.bgStart, .bgEnd], startPoint: .top, endPoint: .bottom)
    }
}

//
//  EnergyCode.swift
//  LOTO2Main
//
//  Shared energy-type definitions used by both the PDF renderer and the form UI.
//  Maps short codes ("E", "H", etc.) to display labels in English and Spanish,
//  plus the associated badge color.
//

import UIKit
import SwiftUI

struct EnergyCode {
    let code: String
    let labelEn: String
    let labelEs: String
    let uiColor: UIColor

    /// SwiftUI Color wrapper for use in views.
    var color: Color { Color(uiColor) }

    static let all: [EnergyCode] = [
        EnergyCode(code: "E",  labelEn: "Electrical", labelEs: "Eléctrico",
                   uiColor: UIColor(red: 1,    green: 0.85, blue: 0,    alpha: 1)),
        EnergyCode(code: "G",  labelEn: "Gas",        labelEs: "Gas",
                   uiColor: UIColor(red: 0.2,  green: 0.6,  blue: 0.2,  alpha: 1)),
        EnergyCode(code: "H",  labelEn: "Hydraulic",  labelEs: "Hidráulico",
                   uiColor: UIColor(red: 0.08, green: 0.47, blue: 0.78, alpha: 1)),
        EnergyCode(code: "P",  labelEn: "Pneumatic",  labelEs: "Neumático",
                   uiColor: UIColor(red: 0.6,  green: 0.6,  blue: 0.6,  alpha: 1)),
        EnergyCode(code: "N",  labelEn: "None",       labelEs: "Ninguno",
                   uiColor: UIColor.darkGray),
        EnergyCode(code: "O",  labelEn: "Mechanical", labelEs: "Mecánico",
                   uiColor: UIColor(red: 0.75, green: 0.08, blue: 0.08, alpha: 1)),
        EnergyCode(code: "OG", labelEn: "Comp. Gas",  labelEs: "Gas Comp.",
                   uiColor: UIColor(red: 0.5,  green: 0.3,  blue: 0.7,  alpha: 1)),
    ]

    /// Returns the EnergyCode matching a given type code, or nil if unknown.
    static func forType(_ type: String) -> EnergyCode? {
        all.first { $0.code == type }
    }
}

//
//  EnergyStep.swift
//  LOTO2Main
//
//  One row of the energy isolation table on a LOTO placard.
//  Maps to the `loto_energy_steps` Supabase table.
//

import Foundation

struct EnergyStep: Codable, Identifiable {
    let id: UUID
    let equipmentId: String       // FK → loto_equipment.equipment_id
    let energyType: String        // "E", "H", "P", "M", "G", "N", "O", "OG"
    let stepNumber: Int           // 1, 2, 3… for equipment with multiple sources of the same type
    let tagDescription: String?   // "Energy Tag and Description" column
    let isolationProcedure: String? // "Isolation Procedure & Lockout Devices" column
    let methodOfVerification: String? // "Method of Verification" column

    enum CodingKeys: String, CodingKey {
        case id
        case equipmentId           = "equipment_id"
        case energyType            = "energy_type"
        case stepNumber            = "step_number"
        case tagDescription        = "tag_description"
        case isolationProcedure    = "isolation_procedure"
        case methodOfVerification  = "method_of_verification"
    }
}

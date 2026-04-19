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
    let tagDescription: String?
    let isolationProcedure: String?
    let methodOfVerification: String?

    // Spanish translations — updated via SupabaseService.updateEnergyStepSpanish()
    var tagDescriptionEs: String?
    var isolationProcedureEs: String?
    var methodOfVerificationEs: String?

    enum CodingKeys: String, CodingKey {
        case id
        case equipmentId              = "equipment_id"
        case energyType               = "energy_type"
        case stepNumber               = "step_number"
        case tagDescription           = "tag_description"
        case isolationProcedure       = "isolation_procedure"
        case methodOfVerification     = "method_of_verification"
        case tagDescriptionEs         = "tag_description_es"
        case isolationProcedureEs     = "isolation_procedure_es"
        case methodOfVerificationEs   = "method_of_verification_es"
    }
}

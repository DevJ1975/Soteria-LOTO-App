//
//  PDFGenerator.swift
//  LOTO2Main
//
//  Renders a 2-page LOTO placard PDF:
//    Page 1 — English
//    Page 2 — Spanish (draft watermark shown until spanishReviewed == true)
//
//  Output: US Letter landscape (792 × 612 pt) per page.
//
//  All UIColor values are set explicitly so the output is
//  correct in both light and dark mode on device.
//

import UIKit
import PDFKit

// MARK: - Language

enum Language { case english, spanish }

// MARK: - PDFGenerator

@MainActor
final class PDFGenerator {

    static let shared = PDFGenerator()
    private init() {}

    private let pageWidth:  CGFloat = 792
    private let pageHeight: CGFloat = 612

    // MARK: - English static text

    private let applicationSteps: [String] = [
        "1. Communicate to AFFECTED employees.",
        "2. Shut down the equipment using normal stopping procedures.",
        "3. Isolate energy sources.",
        "4. Apply lockout devices, locks, and tags.",
        "5. Follow all steps in the energy isolation procedure below.",
        "6. Verify equipment is de-energized by attempting to start up.",
        "7. After test, place controls in a neutral position.",
    ]

    private let standardPurpose = """
The purpose of this procedure is to establish the mandatory requirements for the Control of Hazardous Energy at the Snak King facility in compliance with Cal/OSHA Title 8 §3314. This placard provides specific, standardized instructions to ensure that this equipment is isolated from all electrical, hydraulic, pneumatic, and gravity energy sources before any employee performs maintenance, cleaning, or clearing of jams. These steps are designed to prevent the unexpected startup or release of stored energy, ensuring a safe working environment for all personnel. All employees must strictly adhere to these limitations.
"""

    // MARK: - Spanish static text

    private let applicationStepsEs: [String] = [
        "1. Comunique a los empleados AFECTADOS.",
        "2. Apague el equipo usando los procedimientos normales de paro.",
        "3. Aísle las fuentes de energía.",
        "4. Aplique dispositivos de bloqueo, candados y etiquetas.",
        "5. Siga todos los pasos del procedimiento de aislamiento de energía.",
        "6. Verifique que el equipo esté desenergizado intentando encenderlo.",
        "7. Después de la prueba, coloque los controles en posición neutral.",
    ]

    private let standardPurposeEs = """
El propósito de este procedimiento es establecer los requisitos obligatorios para el Control de Energía Peligrosa en las instalaciones de Snak King, en cumplimiento con Cal/OSHA Título 8 §3314. Esta placa proporciona instrucciones específicas y estandarizadas para garantizar que este equipo esté aislado de todas las fuentes de energía eléctrica, hidráulica, neumática y gravitacional antes de que cualquier empleado realice mantenimiento, limpieza o despeje de atascos.
"""

    // MARK: - Public entry point

    /// Generates a 2-page PDF (English + Spanish). Passing energySteps renders the
    /// actual isolation table; omitting it shows the placeholder text.
    func generate(equipment: Equipment,
                  equipmentPhoto: UIImage?,
                  disconnectPhoto: UIImage?,
                  energySteps: [EnergyStep] = []) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let format   = UIGraphicsImageRendererFormat.default()
        format.scale  = 2
        format.opaque = true

        let equip = equipmentPhoto?.normalizedOrientation()
        let disco  = disconnectPhoto?.normalizedOrientation()

        let enImage = UIGraphicsImageRenderer(size: pageRect.size, format: format).image { _ in
            self.drawPlacard(equipment: equipment, equipmentPhoto: equip,
                             disconnectPhoto: disco, energySteps: energySteps,
                             language: .english, pageRect: pageRect)
        }
        let esImage = UIGraphicsImageRenderer(size: pageRect.size, format: format).image { _ in
            self.drawPlacard(equipment: equipment, equipmentPhoto: equip,
                             disconnectPhoto: disco, energySteps: energySteps,
                             language: .spanish, pageRect: pageRect)
        }

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return pdfRenderer.pdfData { ctx in
            ctx.beginPage(); enImage.draw(in: pageRect)
            ctx.beginPage(); esImage.draw(in: pageRect)
        }
    }

    // MARK: - Layout root

    private func drawPlacard(equipment: Equipment,
                              equipmentPhoto: UIImage?,
                              disconnectPhoto: UIImage?,
                              energySteps: [EnergyStep],
                              language: Language,
                              pageRect: CGRect) {
        UIColor.white.setFill()
        UIRectFill(pageRect)

        var y: CGFloat = 0
        y = drawHeader(equipment, language, pageRect, y)
        y = drawEquipmentBar(equipment, language, pageRect, y)
        y = drawWarningBlock(equipment, language, pageRect, y)
        y = drawPurposeAndSteps(language, pageRect, y)
        y = drawColorCodes(language, pageRect, y)
        y = drawSectionHeader(language, pageRect, y)
        drawEnergySection(equipment: equipment,
                          equipmentPhoto: equipmentPhoto,
                          disconnectPhoto: disconnectPhoto,
                          energySteps: energySteps,
                          language: language,
                          pageRect: pageRect,
                          y: y)

        drawLanguageTag(language, pageRect)

        if language == .spanish && !equipment.spanishReviewed {
            drawDraftWatermark(pageRect)
        }
    }

    // MARK: - Header (yellow band)

    private func drawHeader(_ equipment: Equipment, _ language: Language,
                             _ page: CGRect, _ y: CGFloat) -> CGFloat {
        let h: CGFloat = 44
        let rect = CGRect(x: 0, y: y, width: page.width, height: h)

        UIColor(red: 1, green: 0.85, blue: 0, alpha: 1).setFill()
        UIRectFill(rect)
        UIColor.black.setStroke()
        let border = UIBezierPath(rect: rect); border.lineWidth = 1; border.stroke()

        if let logo = UIImage(named: "SnakKingLogo") {
            logo.draw(in: CGRect(x: 4, y: y + 4, width: 56, height: h - 8))
        } else {
            let snakAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 11), .foregroundColor: UIColor.black
            ]
            "SNAK\nKING".draw(in: CGRect(x: 6, y: y + 6, width: 56, height: h - 6),
                              withAttributes: snakAttr)
        }

        let title = language == .english ? "LOCKOUT/TAGOUT PROCEDURE"
                                         : "PROCEDIMIENTO DE BLOQUEO/ETIQUETADO"
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 15), .foregroundColor: UIColor.black
        ]
        let ts = title.size(withAttributes: titleAttr)
        title.draw(at: CGPoint(x: (page.width - ts.width) / 2, y: y + (h - ts.height) / 2),
                   withAttributes: titleAttr)

        let dateLabel = language == .english ? "Created: \(formattedDate())"
                                             : "Creado: \(formattedDate())"
        let dateAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.black
        ]
        let dts = dateLabel.size(withAttributes: dateAttr)
        dateLabel.draw(at: CGPoint(x: page.width - dts.width - 8, y: y + (h - dts.height) / 2),
                       withAttributes: dateAttr)

        return y + h
    }

    // MARK: - Equipment Bar

    private func drawEquipmentBar(_ equipment: Equipment, _ language: Language,
                                   _ page: CGRect, _ y: CGFloat) -> CGFloat {
        let h: CGFloat = 20
        UIColor(red: 0.85, green: 0.92, blue: 1, alpha: 1).setFill()
        UIRectFill(CGRect(x: 0, y: y, width: page.width, height: h))
        UIColor.black.setStroke()
        let border = UIBezierPath(rect: CGRect(x: 0, y: y, width: page.width, height: h))
        border.lineWidth = 0.5; border.stroke()

        let label = language == .english ? "EQUIPMENT:" : "EQUIPO:"
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 9), .foregroundColor: UIColor.black
        ]
        "\(label)  \(equipment.description)".draw(
            in: CGRect(x: 8, y: y + 4, width: page.width - 80, height: h),
            withAttributes: attr)

        let deptAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.black
        ]
        equipment.department.draw(
            in: CGRect(x: page.width - 120, y: y + 4, width: 112, height: h),
            withAttributes: deptAttr)

        return y + h
    }

    // MARK: - Warning Block (red)

    private func drawWarningBlock(_ equipment: Equipment, _ language: Language,
                                   _ page: CGRect, _ y: CGFloat) -> CGFloat {
        let pad: CGFloat = 6
        let w = page.width - 16

        let headerAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 8), .foregroundColor: UIColor.white
        ]
        let bodyAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7), .foregroundColor: UIColor.white
        ]

        let headerText: String
        let bodyText: String

        if language == .english {
            headerText = "KEEP OUT! HAZARDOUS VOLTAGE AND MOVING PARTS."
            let notesValue = equipment.notes.flatMap { $0.isEmpty ? nil : $0 }
            bodyText = notesValue ?? "Refer to the physical LOTO placard on this equipment for full hazard details."
        } else {
            headerText = "¡MANTÉNGASE ALEJADO! VOLTAJE PELIGROSO Y PIEZAS EN MOVIMIENTO."
            let notesValue = equipment.notesEs.flatMap { $0.isEmpty ? nil : $0 }
                          ?? equipment.notes.flatMap { $0.isEmpty ? nil : $0 }
            bodyText = notesValue ?? "Consulte la placa física de LOTO en este equipo para obtener detalles completos sobre peligros."
        }

        let hH = headerText.boundingRect(
            with: CGSize(width: w, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin, attributes: headerAttr, context: nil).height
        let bH = bodyText.boundingRect(
            with: CGSize(width: w, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin, attributes: bodyAttr, context: nil).height
        let total = pad + hH + 4 + bH + pad

        UIColor(red: 0.75, green: 0.08, blue: 0.08, alpha: 1).setFill()
        UIRectFill(CGRect(x: 0, y: y, width: page.width, height: total))
        headerText.draw(in: CGRect(x: 8, y: y + pad, width: w, height: hH),
                        withAttributes: headerAttr)
        bodyText.draw(in: CGRect(x: 8, y: y + pad + hH + 4, width: w, height: bH),
                      withAttributes: bodyAttr)
        return y + total
    }

    // MARK: - Purpose + Steps

    private func drawPurposeAndSteps(_ language: Language, _ page: CGRect, _ y: CGFloat) -> CGFloat {
        let h: CGFloat = 72
        let split = page.width * 0.55

        UIColor.white.setFill()
        UIRectFill(CGRect(x: 0, y: y, width: page.width, height: h))

        let purpose = language == .english ? standardPurpose : standardPurposeEs
        let steps   = language == .english ? applicationSteps : applicationStepsEs
        let stepsHeader = language == .english ? "LOCKOUT APPLICATION PROCESS"
                                               : "PROCESO DE APLICACIÓN DE BLOQUEO"

        let pAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 6.2), .foregroundColor: UIColor.black
        ]
        purpose.draw(in: CGRect(x: 8, y: y + 4, width: split - 16, height: h - 8),
                     withAttributes: pAttr)

        let hAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 7),
            .foregroundColor: UIColor(red: 0.08, green: 0.18, blue: 0.43, alpha: 1)
        ]
        stepsHeader.draw(in: CGRect(x: split + 4, y: y + 4, width: page.width - split - 8, height: 12),
                         withAttributes: hAttr)

        let sAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 6), .foregroundColor: UIColor.black
        ]
        var sy = y + 16
        for step in steps {
            step.draw(in: CGRect(x: split + 4, y: sy, width: page.width - split - 8, height: 10),
                      withAttributes: sAttr)
            sy += 8
        }

        UIColor.black.setStroke()
        let vLine = UIBezierPath(); vLine.lineWidth = 0.5
        vLine.move(to: CGPoint(x: split, y: y)); vLine.addLine(to: CGPoint(x: split, y: y + h))
        vLine.stroke()
        let hLine = UIBezierPath(); hLine.lineWidth = 0.5
        hLine.move(to: CGPoint(x: 0, y: y + h)); hLine.addLine(to: CGPoint(x: page.width, y: y + h))
        hLine.stroke()

        return y + h
    }

    // MARK: - Color Codes

    private func drawColorCodes(_ language: Language, _ page: CGRect, _ y: CGFloat) -> CGFloat {
        let h: CGFloat = 14
        UIColor(white: 0.93, alpha: 1).setFill()
        UIRectFill(CGRect(x: 0, y: y, width: page.width, height: h))
        UIColor.black.setStroke()
        let border = UIBezierPath(rect: CGRect(x: 0, y: y, width: page.width, height: h))
        border.lineWidth = 0.5; border.stroke()

        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 6.5), .foregroundColor: UIColor.black
        ]
        let cw = page.width / CGFloat(EnergyCode.all.count)
        for (i, ec) in EnergyCode.all.enumerated() {
            let label = language == .english ? ec.labelEn : ec.labelEs
            "\(ec.code) = \(label)".draw(
                in: CGRect(x: CGFloat(i) * cw + 4, y: y + 3, width: cw - 4, height: h),
                withAttributes: attr)
        }
        return y + h
    }

    // MARK: - Section Header (navy)

    private func drawSectionHeader(_ language: Language, _ page: CGRect, _ y: CGFloat) -> CGFloat {
        let h: CGFloat = 13
        UIColor(red: 0.13, green: 0.27, blue: 0.53, alpha: 1).setFill()
        UIRectFill(CGRect(x: 0, y: y, width: page.width, height: h))

        let title = language == .english
            ? "EQUIPMENT IDENTIFICATION AND ENERGY ISOLATION PROCEDURE"
            : "IDENTIFICACIÓN DE EQUIPO Y PROCEDIMIENTO DE AISLAMIENTO DE ENERGÍA"
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 7.5), .foregroundColor: UIColor.white
        ]
        let ts = title.size(withAttributes: attr)
        title.draw(at: CGPoint(x: (page.width - ts.width) / 2, y: y + (h - ts.height) / 2),
                   withAttributes: attr)
        return y + h
    }

    // MARK: - Energy + Photo Section

    private func drawEnergySection(equipment: Equipment,
                                    equipmentPhoto: UIImage?,
                                    disconnectPhoto: UIImage?,
                                    energySteps: [EnergyStep],
                                    language: Language,
                                    pageRect: CGRect,
                                    y: CGFloat) {
        let remaining  = pageRect.height - y - 18
        let photoRowH: CGFloat = 110
        let halfW      = pageRect.width / 2

        let equipLabel = language == .english ? "Photo of Equipment"       : "Foto del Equipo"
        let isoLabel   = language == .english ? "Photo of Isolation Point" : "Foto del Punto de Aislamiento"

        drawPhotoSlot(image: equipmentPhoto,
                      label: equipLabel,
                      rect: CGRect(x: 0, y: y, width: halfW, height: photoRowH))
        drawPhotoSlot(image: disconnectPhoto,
                      label: isoLabel,
                      rect: CGRect(x: halfW, y: y, width: halfW, height: photoRowH))

        let tableY = y + photoRowH
        drawEnergyTable(steps: energySteps, language: language,
                        x: 0, y: tableY, width: pageRect.width,
                        height: remaining - photoRowH)

        drawSignatureBar(language: language, pageRect: pageRect, y: pageRect.height - 18)
    }

    // MARK: - Photo Slot

    private func drawPhotoSlot(image: UIImage?, label: String, rect: CGRect) {
        UIColor.white.setFill(); UIRectFill(rect)
        UIColor.black.setStroke()
        let border = UIBezierPath(rect: rect); border.lineWidth = 0.5; border.stroke()

        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 6.5), .foregroundColor: UIColor.black
        ]
        if let img = image {
            let inset = rect.insetBy(dx: 4, dy: 14)
            let s  = min(inset.width / img.size.width, inset.height / img.size.height)
            let dw = img.size.width * s; let dh = img.size.height * s
            img.draw(in: CGRect(x: inset.midX - dw / 2, y: inset.midY - dh / 2,
                                width: dw, height: dh))
        } else {
            UIColor(white: 0.93, alpha: 1).setFill()
            UIRectFill(rect.insetBy(dx: 4, dy: 14))
            let ph: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 7), .foregroundColor: UIColor.gray
            ]
            "No Photo".draw(in: rect.insetBy(dx: 8, dy: rect.height / 2 - 6),
                            withAttributes: ph)
        }
        label.draw(in: CGRect(x: rect.minX + 2, y: rect.maxY - 13,
                              width: rect.width - 4, height: 11),
                   withAttributes: labelAttr)
    }

    // MARK: - Energy Table

    private func drawEnergyTable(steps: [EnergyStep], language: Language,
                                  x: CGFloat, y: CGFloat,
                                  width: CGFloat, height: CGFloat) {
        let headerH: CGFloat = 16
        UIColor(red: 0.25, green: 0.35, blue: 0.6, alpha: 1).setFill()
        UIRectFill(CGRect(x: x, y: y, width: width, height: headerH))

        let colHeaders = language == .english
            ? ["Energy Tag & Description", "Isolation Procedure & Lockout Devices", "Method of Verification"]
            : ["Etiqueta de Energía y Descripción", "Procedimiento de Aislamiento y Dispositivos", "Método de Verificación"]

        let cw = width / 3
        let hAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 7), .foregroundColor: UIColor.white
        ]
        for (i, h) in colHeaders.enumerated() {
            h.draw(in: CGRect(x: x + CGFloat(i) * cw + 3, y: y + 3, width: cw - 6, height: headerH - 4),
                   withAttributes: hAttr)
        }

        if steps.isEmpty {
            UIColor.white.setFill()
            UIRectFill(CGRect(x: x, y: y + headerH, width: width, height: height - headerH))
            let nAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.gray
            ]
            let msg = language == .english
                ? "Energy isolation procedure data — see physical LOTO placard on equipment."
                : "Datos del procedimiento — consulte la placa física de LOTO en el equipo."
            msg.draw(in: CGRect(x: x + 12, y: y + headerH + 10, width: width - 24, height: 40),
                     withAttributes: nAttr)
        } else {
            let bodyAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 7), .foregroundColor: UIColor.black
            ]
            let badgeAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 7), .foregroundColor: UIColor.white
            ]

            var ry = y + headerH
            let maxY = y + height - 1  // clip rows to available space

            for (i, step) in steps.enumerated() {
                guard ry < maxY else { break }

                let col1: String
                let col2: String
                let col3: String
                if language == .english {
                    col1 = step.tagDescription       ?? ""
                    col2 = step.isolationProcedure   ?? ""
                    col3 = step.methodOfVerification ?? ""
                } else {
                    col1 = step.tagDescriptionEs.flatMap       { $0.isEmpty ? nil : $0 } ?? step.tagDescription       ?? ""
                    col2 = step.isolationProcedureEs.flatMap   { $0.isEmpty ? nil : $0 } ?? step.isolationProcedure   ?? ""
                    col3 = step.methodOfVerificationEs.flatMap { $0.isEmpty ? nil : $0 } ?? step.methodOfVerification ?? ""
                }

                let colW = cw - 8
                let h1 = col1.boundingRect(with: CGSize(width: colW - 22, height: .greatestFiniteMagnitude),
                    options: .usesLineFragmentOrigin, attributes: bodyAttr, context: nil).height
                let h2 = col2.boundingRect(with: CGSize(width: colW,      height: .greatestFiniteMagnitude),
                    options: .usesLineFragmentOrigin, attributes: bodyAttr, context: nil).height
                let h3 = col3.boundingRect(with: CGSize(width: colW,      height: .greatestFiniteMagnitude),
                    options: .usesLineFragmentOrigin, attributes: bodyAttr, context: nil).height
                let rowH = min(max(max(h1, h2), h3) + 8, maxY - ry)

                // Row background
                if i % 2 == 0 { UIColor(white: 0.97, alpha: 1).setFill() } else { UIColor.white.setFill() }
                UIRectFill(CGRect(x: x, y: ry, width: width, height: rowH))

                // Energy type badge
                let ec = EnergyCode.forType(step.energyType)
                (ec?.uiColor ?? UIColor.darkGray).setFill()
                let badgeRect = CGRect(x: x + 3, y: ry + 3, width: 18, height: 10)
                UIBezierPath(roundedRect: badgeRect, cornerRadius: 2).fill()
                step.energyType.draw(in: badgeRect, withAttributes: badgeAttr)

                col1.draw(in: CGRect(x: x + 24, y: ry + 4, width: cw - 28, height: rowH - 8),
                          withAttributes: bodyAttr)
                col2.draw(in: CGRect(x: x + cw + 4,     y: ry + 4, width: cw - 8, height: rowH - 8),
                          withAttributes: bodyAttr)
                col3.draw(in: CGRect(x: x + cw * 2 + 4, y: ry + 4, width: cw - 8, height: rowH - 8),
                          withAttributes: bodyAttr)

                // Row divider
                UIColor(white: 0.8, alpha: 1).setStroke()
                let line = UIBezierPath(); line.lineWidth = 0.25
                line.move(to: CGPoint(x: x, y: ry + rowH))
                line.addLine(to: CGPoint(x: x + width, y: ry + rowH))
                line.stroke()

                // Column dividers
                UIColor(white: 0.75, alpha: 1).setStroke()
                for col in 1...2 {
                    let cx = x + CGFloat(col) * cw
                    let dl = UIBezierPath(); dl.lineWidth = 0.25
                    dl.move(to: CGPoint(x: cx, y: ry))
                    dl.addLine(to: CGPoint(x: cx, y: ry + rowH))
                    dl.stroke()
                }

                ry += rowH
            }

            // Fill any leftover space
            if ry < maxY {
                UIColor.white.setFill()
                UIRectFill(CGRect(x: x, y: ry, width: width, height: maxY - ry))
            }
        }

        // Table border
        UIColor.black.setStroke()
        let border = UIBezierPath(rect: CGRect(x: x, y: y, width: width, height: height))
        border.lineWidth = 0.5; border.stroke()
    }

    // MARK: - Signature Bar

    private func drawSignatureBar(language: Language, pageRect: CGRect, y: CGFloat) {
        let h: CGFloat = 18
        UIColor(white: 0.97, alpha: 1).setFill()
        UIRectFill(CGRect(x: 0, y: y, width: pageRect.width, height: h))
        UIColor.black.setStroke()
        let border = UIBezierPath(rect: CGRect(x: 0, y: y, width: pageRect.width, height: h))
        border.lineWidth = 0.5; border.stroke()

        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 6), .foregroundColor: UIColor.black
        ]
        let labels = language == .english
            ? ["Signature: _______________", "Date: _______________",
               "Dept: _______________", "See PM Store in PT Folder"]
            : ["Firma: _______________", "Fecha: _______________",
               "Depto: _______________", "Ver PM Store en carpeta PT"]
        let cw = pageRect.width / CGFloat(labels.count)
        for (i, l) in labels.enumerated() {
            l.draw(in: CGRect(x: CGFloat(i) * cw + 4, y: y + 4, width: cw - 8, height: h - 4),
                   withAttributes: attr)
        }
    }

    // MARK: - Language Corner Tag

    private func drawLanguageTag(_ language: Language, _ page: CGRect) {
        let tagW: CGFloat = 28, tagH: CGFloat = 14
        let tagX = page.width - tagW - 2
        let tagY: CGFloat = 2

        let color: UIColor = language == .english
            ? UIColor(red: 0.13, green: 0.27, blue: 0.53, alpha: 0.85)
            : UIColor(red: 0.65, green: 0.1,  blue: 0.1,  alpha: 0.85)
        color.setFill()
        UIBezierPath(roundedRect: CGRect(x: tagX, y: tagY, width: tagW, height: tagH),
                     cornerRadius: 3).fill()

        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 8), .foregroundColor: UIColor.white
        ]
        let text = language == .english ? "EN" : "ES"
        let ts = text.size(withAttributes: attr)
        text.draw(at: CGPoint(x: tagX + (tagW - ts.width) / 2,
                              y: tagY + (tagH - ts.height) / 2),
                  withAttributes: attr)
    }

    // MARK: - Draft Watermark (Spanish page, unreviewed)

    private func drawDraftWatermark(_ page: CGRect) {
        let text = "BORRADOR — NO REVISADO"
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 44),
            .foregroundColor: UIColor(red: 0.5, green: 0, blue: 0, alpha: 0.12)
        ]
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.saveGState()
        ctx.translateBy(x: page.width / 2, y: page.height / 2)
        ctx.rotate(by: -CGFloat.pi / 6)
        let ts = text.size(withAttributes: attr)
        text.draw(at: CGPoint(x: -ts.width / 2, y: -ts.height / 2), withAttributes: attr)
        ctx.restoreGState()
    }

    // MARK: - Date

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
    }()

    private func formattedDate() -> String { Self.dateFormatter.string(from: Date()) }
}

// MARK: - UIImage orientation fix

private extension UIImage {
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }
}

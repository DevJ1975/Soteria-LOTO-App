//
//  PDFGenerator.swift
//  LOTO2Main
//
//  Renders a LOTO placard PDF matching the Snak King
//  LOCKOUT/TAGOUT PROCEDURE format.
//
//  Output: US Letter landscape (792 × 612 pt) PDF.
//
//  All text attributes explicitly set UIColor.black (or white where needed)
//  so the output is correct in both light and dark mode on device.
//

import UIKit
import PDFKit

@MainActor
final class PDFGenerator {

    static let shared = PDFGenerator()
    private init() {}

    private let pageWidth:  CGFloat = 792
    private let pageHeight: CGFloat = 612

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

    // MARK: - Public

    func generate(equipment: Equipment, equipmentPhoto: UIImage?, disconnectPhoto: UIImage?) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        // Render to UIImage first — UIGraphicsImageRenderer always uses correct
        // UIKit coordinates (top-left origin, Y down) regardless of device mode.
        // opaque = true + white fill prevents dark-mode transparency issues.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale  = 2
        format.opaque = true
        let placardImage = UIGraphicsImageRenderer(size: pageRect.size, format: format).image { _ in
            self.drawPlacard(
                equipment: equipment,
                equipmentPhoto: equipmentPhoto?.normalizedOrientation(),
                disconnectPhoto: disconnectPhoto?.normalizedOrientation(),
                pageRect: pageRect
            )
        }

        // Wrap the image in a single-page PDF.
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return pdfRenderer.pdfData { ctx in
            ctx.beginPage()
            placardImage.draw(in: pageRect)
        }
    }

    // MARK: - Layout

    private func drawPlacard(equipment: Equipment,
                              equipmentPhoto: UIImage?,
                              disconnectPhoto: UIImage?,
                              pageRect: CGRect) {
        // Explicit white fill — prevents dark-mode transparency bleed
        UIColor.white.setFill()
        UIRectFill(pageRect)

        var y: CGFloat = 0
        y = drawHeader(equipment, pageRect, y)
        y = drawEquipmentBar(equipment, pageRect, y)
        y = drawWarningBlock(equipment, pageRect, y)
        y = drawPurposeAndSteps(pageRect, y)
        y = drawColorCodes(pageRect, y)
        y = drawSectionHeader(pageRect, y)
        drawEnergySection(equipment: equipment,
                          equipmentPhoto: equipmentPhoto,
                          disconnectPhoto: disconnectPhoto,
                          pageRect: pageRect,
                          y: y)
    }

    // MARK: - Header (yellow band)

    private func drawHeader(_ equipment: Equipment, _ page: CGRect, _ y: CGFloat) -> CGFloat {
        let h: CGFloat = 44
        let rect = CGRect(x: 0, y: y, width: page.width, height: h)

        UIColor(red: 1, green: 0.85, blue: 0, alpha: 1).setFill()
        UIRectFill(rect)
        UIColor.black.setStroke()
        let border = UIBezierPath(rect: rect)
        border.lineWidth = 1
        border.stroke()

        if let logo = UIImage(named: "SnakKingLogo") {
            logo.draw(in: CGRect(x: 4, y: y + 4, width: 56, height: h - 8))
        } else {
            let snakAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 11),
                .foregroundColor: UIColor.black
            ]
            "SNAK\nKING".draw(in: CGRect(x: 6, y: y + 6, width: 56, height: h - 6),
                              withAttributes: snakAttr)
        }

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 15),
            .foregroundColor: UIColor.black
        ]
        let title = "LOCKOUT/TAGOUT PROCEDURE"
        let ts = title.size(withAttributes: titleAttr)
        title.draw(at: CGPoint(x: (page.width - ts.width) / 2, y: y + (h - ts.height) / 2),
                   withAttributes: titleAttr)

        let dateAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.black
        ]
        let ds  = "Created: \(formattedDate())"
        let dts = ds.size(withAttributes: dateAttr)
        ds.draw(at: CGPoint(x: page.width - dts.width - 8, y: y + (h - dts.height) / 2),
                withAttributes: dateAttr)

        return y + h
    }

    // MARK: - Equipment Bar

    private func drawEquipmentBar(_ equipment: Equipment, _ page: CGRect, _ y: CGFloat) -> CGFloat {
        let h: CGFloat = 20
        let rect = CGRect(x: 0, y: y, width: page.width, height: h)

        UIColor(red: 0.85, green: 0.92, blue: 1, alpha: 1).setFill()
        UIRectFill(rect)
        UIColor.black.setStroke()
        let border = UIBezierPath(rect: rect)
        border.lineWidth = 0.5
        border.stroke()

        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 9),
            .foregroundColor: UIColor.black
        ]
        "EQUIPMENT:  \(equipment.description)".draw(
            in: CGRect(x: 8, y: y + 4, width: page.width - 80, height: h),
            withAttributes: attr)

        let deptAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.black
        ]
        equipment.department.draw(
            in: CGRect(x: page.width - 120, y: y + 4, width: 112, height: h),
            withAttributes: deptAttr)

        return y + h
    }

    // MARK: - Warning Block (red)

    private func drawWarningBlock(_ equipment: Equipment, _ page: CGRect, _ y: CGFloat) -> CGFloat {
        let pad: CGFloat = 6
        let w = page.width - 16
        let headerAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 8),
            .foregroundColor: UIColor.white
        ]
        let bodyAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7),
            .foregroundColor: UIColor.white
        ]

        let headerText = "KEEP OUT! HAZARDOUS VOLTAGE AND MOVING PARTS."
        let notesValue = equipment.notes.flatMap { $0.isEmpty ? nil : $0 }
        let bodyText   = notesValue ?? "Refer to the physical LOTO placard on this equipment for full hazard details."

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

    private func drawPurposeAndSteps(_ page: CGRect, _ y: CGFloat) -> CGFloat {
        let h: CGFloat = 72
        let split = page.width * 0.55

        UIColor.white.setFill()
        UIRectFill(CGRect(x: 0, y: y, width: page.width, height: h))

        let pAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 6.2),
            .foregroundColor: UIColor.black
        ]
        standardPurpose.draw(
            in: CGRect(x: 8, y: y + 4, width: split - 16, height: h - 8),
            withAttributes: pAttr)

        let hAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 7),
            .foregroundColor: UIColor(red: 0.08, green: 0.18, blue: 0.43, alpha: 1)
        ]
        "LOCKOUT APPLICATION PROCESS".draw(
            in: CGRect(x: split + 4, y: y + 4, width: page.width - split - 8, height: 12),
            withAttributes: hAttr)

        let sAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 6),
            .foregroundColor: UIColor.black
        ]
        var sy = y + 16
        for step in applicationSteps {
            step.draw(in: CGRect(x: split + 4, y: sy, width: page.width - split - 8, height: 10),
                      withAttributes: sAttr)
            sy += 8
        }

        UIColor.black.setStroke()
        let vLine = UIBezierPath()
        vLine.lineWidth = 0.5
        vLine.move(to: CGPoint(x: split, y: y))
        vLine.addLine(to: CGPoint(x: split, y: y + h))
        vLine.stroke()

        let hLine = UIBezierPath()
        hLine.lineWidth = 0.5
        hLine.move(to: CGPoint(x: 0, y: y + h))
        hLine.addLine(to: CGPoint(x: page.width, y: y + h))
        hLine.stroke()

        return y + h
    }

    // MARK: - Color Codes

    private func drawColorCodes(_ page: CGRect, _ y: CGFloat) -> CGFloat {
        let h: CGFloat = 14
        let rect = CGRect(x: 0, y: y, width: page.width, height: h)

        UIColor(white: 0.93, alpha: 1).setFill()
        UIRectFill(rect)
        UIColor.black.setStroke()
        let border = UIBezierPath(rect: rect)
        border.lineWidth = 0.5
        border.stroke()

        let codes = [("E", "Electrical"), ("G", "Gas"), ("H", "Hydraulic"),
                     ("P", "Pneumatic"),  ("N", "None"), ("O", "Mechanical"), ("OG", "Compressed Gas")]
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 6.5),
            .foregroundColor: UIColor.black
        ]
        let cw = page.width / CGFloat(codes.count)
        for (i, (c, l)) in codes.enumerated() {
            "\(c) = \(l)".draw(
                in: CGRect(x: CGFloat(i) * cw + 4, y: y + 3, width: cw - 4, height: h),
                withAttributes: attr)
        }
        return y + h
    }

    // MARK: - Section Header (navy)

    private func drawSectionHeader(_ page: CGRect, _ y: CGFloat) -> CGFloat {
        let h: CGFloat = 13
        let rect = CGRect(x: 0, y: y, width: page.width, height: h)

        UIColor(red: 0.13, green: 0.27, blue: 0.53, alpha: 1).setFill()
        UIRectFill(rect)

        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 7.5),
            .foregroundColor: UIColor.white
        ]
        let t  = "EQUIPMENT IDENTIFICATION AND ENERGY ISOLATION PROCEDURE"
        let ts = t.size(withAttributes: attr)
        t.draw(at: CGPoint(x: (page.width - ts.width) / 2, y: y + (h - ts.height) / 2),
               withAttributes: attr)
        return y + h
    }

    // MARK: - Energy + Photo Section

    private func drawEnergySection(equipment: Equipment,
                                    equipmentPhoto: UIImage?,
                                    disconnectPhoto: UIImage?,
                                    pageRect: CGRect,
                                    y: CGFloat) {
        let remaining  = pageRect.height - y - 18
        let photoRowH: CGFloat = 110
        let halfW      = pageRect.width / 2

        drawPhotoSlot(image: equipmentPhoto,
                      label: "Photo of Equipment",
                      rect: CGRect(x: 0, y: y, width: halfW, height: photoRowH))
        drawPhotoSlot(image: disconnectPhoto,
                      label: "Photo of Isolation / Disconnect",
                      rect: CGRect(x: halfW, y: y, width: halfW, height: photoRowH))

        let tableY = y + photoRowH
        drawEnergyPlaceholder(x: 0, y: tableY,
                              width: pageRect.width,
                              height: remaining - photoRowH)
        drawSignatureBar(pageRect: pageRect, y: pageRect.height - 18)
    }

    private func drawPhotoSlot(image: UIImage?, label: String, rect: CGRect) {
        UIColor.white.setFill()
        UIRectFill(rect)
        UIColor.black.setStroke()
        let border = UIBezierPath(rect: rect)
        border.lineWidth = 0.5
        border.stroke()

        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 6.5),
            .foregroundColor: UIColor.black
        ]

        if let img = image {
            let inset = rect.insetBy(dx: 4, dy: 14)
            let s  = min(inset.width / img.size.width, inset.height / img.size.height)
            let dw = img.size.width * s
            let dh = img.size.height * s
            img.draw(in: CGRect(x: inset.midX - dw / 2, y: inset.midY - dh / 2,
                                width: dw, height: dh))
        } else {
            UIColor(white: 0.93, alpha: 1).setFill()
            UIRectFill(rect.insetBy(dx: 4, dy: 14))
            let ph: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 7),
                .foregroundColor: UIColor.gray
            ]
            "No Photo".draw(in: rect.insetBy(dx: 8, dy: rect.height / 2 - 6),
                            withAttributes: ph)
        }

        label.draw(in: CGRect(x: rect.minX + 2, y: rect.maxY - 13,
                              width: rect.width - 4, height: 11),
                   withAttributes: labelAttr)
    }

    private func drawEnergyPlaceholder(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        let headerH: CGFloat = 16

        UIColor(red: 0.25, green: 0.35, blue: 0.6, alpha: 1).setFill()
        UIRectFill(CGRect(x: x, y: y, width: width, height: headerH))

        let headers = ["Energy Tag & Type", "Isolation Procedure & Switching Device", "Method of Verification"]
        let cw = width / CGFloat(headers.count)
        let hAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 7),
            .foregroundColor: UIColor.white
        ]
        for (i, h) in headers.enumerated() {
            h.draw(in: CGRect(x: x + CGFloat(i) * cw + 3, y: y + 3,
                              width: cw - 6, height: headerH - 4),
                   withAttributes: hAttr)
        }

        UIColor.white.setFill()
        UIRectFill(CGRect(x: x, y: y + headerH, width: width, height: height - headerH))

        UIColor.black.setStroke()
        let border = UIBezierPath(rect: CGRect(x: x, y: y, width: width, height: height))
        border.lineWidth = 0.5
        border.stroke()

        let nAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.gray
        ]
        "Energy isolation procedure data — see physical LOTO placard on equipment.".draw(
            in: CGRect(x: x + 12, y: y + headerH + 10, width: width - 24, height: 40),
            withAttributes: nAttr)
    }

    private func drawSignatureBar(pageRect: CGRect, y: CGFloat) {
        let h: CGFloat = 18
        let rect = CGRect(x: 0, y: y, width: pageRect.width, height: h)

        UIColor(white: 0.97, alpha: 1).setFill()
        UIRectFill(rect)
        UIColor.black.setStroke()
        let border = UIBezierPath(rect: rect)
        border.lineWidth = 0.5
        border.stroke()

        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 6),
            .foregroundColor: UIColor.black
        ]
        let labels = ["Signature: _______________", "Date: _______________",
                      "Dept: _______________", "See PM Store in PT Folder"]
        let cw = pageRect.width / CGFloat(labels.count)
        for (i, l) in labels.enumerated() {
            l.draw(in: CGRect(x: CGFloat(i) * cw + 4, y: y + 4, width: cw - 8, height: h - 4),
                   withAttributes: attr)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private func formattedDate() -> String {
        Self.dateFormatter.string(from: Date())
    }
}

// MARK: - UIImage orientation fix

private extension UIImage {
    /// Returns a copy redrawn with .up orientation so camera photos draw correctly.
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

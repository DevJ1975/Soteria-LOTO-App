//
//  StatusReportGenerator.swift
//  LOTO2Main
//
//  Generates a multi-page PDF status report for LOTO placards.
//  Page 1  — executive summary: overall stats + per-department table
//  Page 2+ — full equipment list (paginated, active items only)
//
//  Output: US Letter portrait (612 × 792 pt), same drawing approach as PDFGenerator.
//

import UIKit

// MARK: - StatusReportGenerator

@MainActor
final class StatusReportGenerator {

    static let shared = StatusReportGenerator()
    private init() {}

    private let pageW: CGFloat = 612
    private let pageH: CGFloat = 792
    private let margin: CGFloat = 36

    // Brand colours — match PDFGenerator palette
    private let navyColor   = UIColor(red: 0.13, green: 0.27, blue: 0.53, alpha: 1)
    private let yellowColor = UIColor(red: 1.00, green: 0.85, blue: 0.00, alpha: 1)
    private let greenColor  = UIColor(red: 0.13, green: 0.55, blue: 0.13, alpha: 1)
    private let amberColor  = UIColor(red: 0.85, green: 0.55, blue: 0.00, alpha: 1)
    private let redColor    = UIColor(red: 0.75, green: 0.08, blue: 0.08, alpha: 1)
    private let lightGray   = UIColor(white: 0.93, alpha: 1)
    private let rowAlt      = UIColor(white: 0.97, alpha: 1)

    // MARK: - Public Entry Point

    struct ReportData {
        let equipment:       [Equipment]
        let departments:     [String]
        let deptActive:      [String: Int]
        let deptComplete:    [String: Int]
        let signOffs:        [String: PlacardViewModel.DepartmentSignOff]
        let decommissioned:  Set<String>
        let countActive:     Int
        let countComplete:   Int
        let countPartial:    Int
        let countMissing:    Int
    }

    func generate(_ data: ReportData) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
        return renderer.pdfData { ctx in
            // Page 1 — summary
            ctx.beginPage()
            drawSummaryPage(data, ctx: ctx.cgContext)

            // Page 2+ — equipment list
            let active = data.equipment
                .filter { !data.decommissioned.contains($0.equipmentId) }
                .sorted { $0.equipmentId < $1.equipmentId }

            if !active.isEmpty {
                drawEquipmentPages(active, data: data, ctx: ctx)
            }
        }
    }

    // MARK: - Page 1: Summary

    private func drawSummaryPage(_ data: ReportData, ctx: CGContext) {
        var y = drawReportHeader(ctx: ctx)
        y = drawOverallStats(data, y: y, ctx: ctx)
        y = drawProgressBar(data, y: y, ctx: ctx)
        y += 14
        y = drawDeptTable(data, y: y, ctx: ctx)
    }

    // MARK: - Header Band

    private func drawReportHeader(ctx: CGContext) -> CGFloat {
        let h: CGFloat = 52
        yellowColor.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: pageW, height: h))

        // Title
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: navyColor
        ]
        "LOTO PLACARD STATUS REPORT".draw(
            in: CGRect(x: margin, y: 10, width: pageW - margin * 2, height: 22),
            withAttributes: titleAttr
        )

        // Date
        let dateAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: navyColor
        ]
        let dateStr = "Generated: \(formattedDateTime())"
        let dateSize = (dateStr as NSString).size(withAttributes: dateAttr)
        dateStr.draw(
            at: CGPoint(x: pageW - margin - dateSize.width, y: 34),
            withAttributes: dateAttr
        )

        // Subtitle
        let subAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: navyColor
        ]
        "Snak King — LOTO Compliance Tracking".draw(
            in: CGRect(x: margin, y: 32, width: 300, height: 16),
            withAttributes: subAttr
        )

        return h + 14
    }

    // MARK: - Overall Stats Bar

    private func drawOverallStats(_ data: ReportData, y: CGFloat, ctx: CGContext) -> CGFloat {
        let cells: [(label: String, value: Int, color: UIColor)] = [
            ("Total Active",  data.countActive,   navyColor),
            ("Complete",      data.countComplete, greenColor),
            ("Partial",       data.countPartial,  amberColor),
            ("Missing",       data.countMissing,  redColor),
            ("Decommissioned",
             data.equipment.count - data.countActive,
             UIColor.systemGray),
        ]

        let cellW = (pageW - margin * 2) / CGFloat(cells.count)
        let boxH: CGFloat = 52
        let boxY = y

        for (i, cell) in cells.enumerated() {
            let x = margin + CGFloat(i) * cellW
            let rect = CGRect(x: x, y: boxY, width: cellW, height: boxH)

            // Background
            cell.color.withAlphaComponent(0.10).setFill()
            UIBezierPath(roundedRect: rect.insetBy(dx: 3, dy: 0), cornerRadius: 4).fill()

            // Border
            cell.color.withAlphaComponent(0.35).setStroke()
            let border = UIBezierPath(roundedRect: rect.insetBy(dx: 3, dy: 0), cornerRadius: 4)
            border.lineWidth = 0.5
            border.stroke()

            // Value
            let valAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: cell.color
            ]
            let valStr = "\(cell.value)"
            let valSize = (valStr as NSString).size(withAttributes: valAttr)
            valStr.draw(at: CGPoint(x: x + (cellW - valSize.width) / 2, y: boxY + 8), withAttributes: valAttr)

            // Label
            let lblAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 7.5, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]
            let lblSize = (cell.label as NSString).size(withAttributes: lblAttr)
            cell.label.draw(at: CGPoint(x: x + (cellW - lblSize.width) / 2, y: boxY + 33), withAttributes: lblAttr)
        }

        return boxY + boxH + 12
    }

    // MARK: - Progress Bar

    private func drawProgressBar(_ data: ReportData, y: CGFloat, ctx: CGContext) -> CGFloat {
        let barW = pageW - margin * 2
        let barH: CGFloat = 14
        let pct = data.countActive > 0
            ? Double(data.countComplete) / Double(data.countActive)
            : 0

        // Background track
        lightGray.setFill()
        UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: barW, height: barH), cornerRadius: 7).fill()

        // Fill
        if pct > 0 {
            let fillColor = pct == 1.0 ? greenColor : navyColor
            fillColor.setFill()
            UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: barW * CGFloat(pct), height: barH), cornerRadius: 7).fill()
        }

        // Percentage label
        let pctStr = "\(Int(pct * 100))% complete — \(data.countComplete) of \(data.countActive) placards done"
        let pctAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: pct > 0.4 ? UIColor.white : navyColor
        ]
        pctStr.draw(in: CGRect(x: margin + 6, y: y + 2, width: barW - 12, height: 12), withAttributes: pctAttr)

        return y + barH + 4
    }

    // MARK: - Department Table

    private func drawDeptTable(_ data: ReportData, y: CGFloat, ctx: CGContext) -> CGFloat {
        let colW: [CGFloat] = [180, 52, 52, 52, 52, 52, 70]  // Dept, Total, Complete, Partial, Missing, %, Signed Off
        let headers = ["Department", "Total", "Complete", "Partial", "Missing", "%", "Signed Off"]
        let rowH: CGFloat = 16
        let tableW = pageW - margin * 2
        var curY = y

        // Section label
        let sectionAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: UIColor.darkGray
        ]
        "DEPARTMENT BREAKDOWN".draw(at: CGPoint(x: margin, y: curY), withAttributes: sectionAttr)
        curY += 14

        // Header row
        navyColor.setFill()
        ctx.fill(CGRect(x: margin, y: curY, width: tableW, height: rowH))

        var colX = margin
        for (i, header) in headers.enumerated() {
            let hAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 7.5, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            header.draw(in: CGRect(x: colX + 3, y: curY + 3, width: colW[i] - 6, height: rowH - 4), withAttributes: hAttr)
            colX += colW[i]
        }
        curY += rowH

        // Data rows
        for (rowIdx, dept) in data.departments.enumerated() {
            let total    = data.deptActive[dept]   ?? 0
            let complete = data.deptComplete[dept] ?? 0
            let partial  = data.equipment.filter { !data.decommissioned.contains($0.equipmentId) && $0.department == dept && $0.photoStatus == "partial" }.count
            let missing  = total - complete - partial
            let pct      = total > 0 ? Int(Double(complete) / Double(total) * 100) : 0
            let signedOff = data.signOffs[dept] != nil

            // Row background
            let isComplete = pct == 100
            if isComplete {
                greenColor.withAlphaComponent(0.08).setFill()
            } else if rowIdx % 2 == 0 {
                UIColor.white.setFill()
            } else {
                rowAlt.setFill()
            }
            ctx.fill(CGRect(x: margin, y: curY, width: tableW, height: rowH))

            let rowValues: [String] = [
                dept,
                "\(total)",
                "\(complete)",
                "\(partial)",
                "\(missing)",
                "\(pct)%",
                signedOff ? "✓ \(data.signOffs[dept]!.supervisorName)" : "—"
            ]
            let rowColors: [UIColor] = [
                .black,
                navyColor,
                greenColor,
                amberColor,
                missing > 0 ? redColor : .darkGray,
                pct == 100 ? greenColor : .darkGray,
                signedOff ? greenColor : .lightGray
            ]

            colX = margin
            for (i, val) in rowValues.enumerated() {
                let attr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: i == 0 ? 8 : 7.5, weight: i == 0 ? .medium : .regular),
                    .foregroundColor: rowColors[i]
                ]
                val.draw(in: CGRect(x: colX + 3, y: curY + 3, width: colW[i] - 6, height: rowH - 4), withAttributes: attr)
                colX += colW[i]
            }

            // Bottom divider
            UIColor.lightGray.withAlphaComponent(0.4).setStroke()
            let line = UIBezierPath()
            line.move(to: CGPoint(x: margin, y: curY + rowH))
            line.addLine(to: CGPoint(x: margin + tableW, y: curY + rowH))
            line.lineWidth = 0.3
            line.stroke()

            curY += rowH

            // Overflow to next page? (leave space for footer)
            if curY > pageH - 50 { break }
        }

        // Table outer border
        navyColor.withAlphaComponent(0.4).setStroke()
        let border = UIBezierPath(rect: CGRect(x: margin, y: y + 14, width: tableW, height: curY - (y + 14)))
        border.lineWidth = 0.5
        border.stroke()

        return curY
    }

    // MARK: - Page 2+: Equipment List

    private func drawEquipmentPages(_ items: [Equipment], data: ReportData, ctx: UIGraphicsPDFRendererContext) {
        let colW: [CGFloat] = [90, 220, 110, 60, 60]  // ID, Description, Dept, Status, Verified
        let headers = ["Equipment ID", "Description", "Department", "Status", "Verified"]
        let rowH: CGFloat = 14
        let tableW = pageW - margin * 2
        let headerH: CGFloat = 16

        var pageNum = 2
        var itemIdx = 0
        let totalPages = estimatePageCount(items: items, rowH: rowH)

        while itemIdx < items.count {
            ctx.beginPage()
            let cgCtx = ctx.cgContext

            // Page header
            var y = drawReportHeader(ctx: cgCtx)

            // Section label
            let sectionAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .bold),
                .foregroundColor: UIColor.darkGray
            ]
            "EQUIPMENT LIST — ALL ACTIVE PLACARDS".draw(at: CGPoint(x: margin, y: y), withAttributes: sectionAttr)
            y += 14

            // Column header
            navyColor.setFill()
            cgCtx.fill(CGRect(x: margin, y: y, width: tableW, height: headerH))
            var colX = margin
            for (i, h) in headers.enumerated() {
                let hAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 7.5, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                h.draw(in: CGRect(x: colX + 3, y: y + 3, width: colW[i] - 6, height: headerH - 4), withAttributes: hAttr)
                colX += colW[i]
            }
            y += headerH

            var rowIdx = 0
            while itemIdx < items.count && y + rowH < pageH - 30 {
                let item = items[itemIdx]

                // Row background
                if rowIdx % 2 == 0 { UIColor.white.setFill() } else { rowAlt.setFill() }
                cgCtx.fill(CGRect(x: margin, y: y, width: tableW, height: rowH))

                let statusColor: UIColor
                switch item.photoStatus {
                case "complete": statusColor = greenColor
                case "partial":  statusColor = amberColor
                default:         statusColor = redColor
                }

                let vals: [String] = [
                    item.equipmentId,
                    item.shortName,
                    item.department,
                    item.photoStatus.capitalized,
                    item.verified ? "✓" : "—"
                ]
                let colors: [UIColor] = [
                    navyColor, .black, .darkGray, statusColor,
                    item.verified ? greenColor : UIColor.lightGray
                ]

                colX = margin
                for (i, val) in vals.enumerated() {
                    let attr: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 7, weight: i == 0 ? .semibold : .regular),
                        .foregroundColor: colors[i]
                    ]
                    val.draw(in: CGRect(x: colX + 3, y: y + 2, width: colW[i] - 6, height: rowH - 2), withAttributes: attr)
                    colX += colW[i]
                }

                // Row divider
                UIColor.lightGray.withAlphaComponent(0.4).setStroke()
                let line = UIBezierPath()
                line.move(to: CGPoint(x: margin, y: y + rowH))
                line.addLine(to: CGPoint(x: margin + tableW, y: y + rowH))
                line.lineWidth = 0.25
                line.stroke()

                y += rowH
                itemIdx += 1
                rowIdx += 1
            }

            // Table border
            navyColor.withAlphaComponent(0.4).setStroke()
            let border = UIBezierPath(rect: CGRect(x: margin, y: y - rowH * CGFloat(rowIdx) - headerH, width: tableW, height: rowH * CGFloat(rowIdx) + headerH))
            border.lineWidth = 0.5
            border.stroke()

            // Page footer
            drawPageFooter(page: pageNum, total: totalPages + 1, ctx: cgCtx)
            pageNum += 1
        }
    }

    // MARK: - Page Footer

    private func drawPageFooter(page: Int, total: Int, ctx: CGContext) {
        let footerAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7, weight: .regular),
            .foregroundColor: UIColor.lightGray
        ]
        let left = "LOTO Status Report — \(formattedDateTime())"
        let right = "Page \(page) of \(total)"
        left.draw(at: CGPoint(x: margin, y: pageH - 20), withAttributes: footerAttr)
        let rightSize = (right as NSString).size(withAttributes: footerAttr)
        right.draw(at: CGPoint(x: pageW - margin - rightSize.width, y: pageH - 20), withAttributes: footerAttr)

        // Footer line
        UIColor.lightGray.withAlphaComponent(0.5).setStroke()
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: pageH - 26))
        line.addLine(to: CGPoint(x: pageW - margin, y: pageH - 26))
        line.lineWidth = 0.3
        line.stroke()
    }

    // MARK: - Helpers

    private func estimatePageCount(items: [Equipment], rowH: CGFloat) -> Int {
        let usableH = pageH - 110  // header + section label + col header
        let rowsPerPage = Int(usableH / rowH)
        return max(1, Int(ceil(Double(items.count) / Double(rowsPerPage))))
    }

    private func formattedDateTime() -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: Date())
    }
}

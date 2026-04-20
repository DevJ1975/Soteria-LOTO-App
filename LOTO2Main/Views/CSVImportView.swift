//
//  CSVImportView.swift
//  LOTO2Main
//
//  Imports missing equipment from a CSV file — pick from Files app, email,
//  or any document provider.  Existing equipment_id values are automatically
//  skipped so re-importing is always safe.
//
//  Required CSV columns (header row required, names are case-insensitive):
//    equipment_id, description, department, prefix
//
//  Optional columns (safe defaults applied when absent):
//    needs_equip_photo  — true / false  (default: true)
//    needs_iso_photo    — true / false  (default: true)
//    notes              — free text
//

import SwiftUI
import UniformTypeIdentifiers

struct CSVImportView: View {

    @Environment(PlacardViewModel.self) private var vm
    @Environment(\.dismiss)            private var dismiss

    @State private var showFilePicker = false
    @State private var fileName:       String?
    @State private var parsedRows:     [ParsedRow] = []
    @State private var parseError:     String?
    @State private var isImporting     = false
    @State private var importResult:   ImportResult?

    // MARK: - Models

    struct ParsedRow: Identifiable {
        let id              = UUID()
        let equipmentId:     String
        let description:     String
        let department:      String
        let prefix:          String
        let needsEquipPhoto: Bool
        let needsIsoPhoto:   Bool
        let notes:           String?
        let isDuplicate:     Bool    // already exists in Supabase / local cache
        let error:           String? // nil = valid
        var isNew: Bool { error == nil && !isDuplicate }
    }

    struct ImportResult { let inserted: Int; let skipped: Int }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                fileSection
                if !parsedRows.isEmpty  { previewSection }
                if importResult != nil  { resultSection  }
                if !newRows.isEmpty && importResult == nil { importSection }
            }
            .navigationTitle("Import Equipment CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false,
            onCompletion: handleFilePick
        )
    }

    // MARK: - Sections

    private var fileSection: some View {
        Section {
            Button {
                parseError   = nil
                parsedRows   = []
                importResult = nil
                fileName     = nil
                showFilePicker = true
            } label: {
                Label(fileName ?? "Choose CSV File…", systemImage: "doc.badge.plus")
            }
            if let err = parseError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.statusError)
                    .font(.caption)
            }
        } header: {
            Text("CSV File")
        } footer: {
            Text("Required columns: equipment_id, description, department, prefix\n" +
                 "Optional: needs_equip_photo, needs_iso_photo, notes")
                .font(.caption2)
        }
    }

    private var previewSection: some View {
        Section {
            // Summary bar
            HStack(spacing: 0) {
                summaryCell(count: newRows.count,       label: "New",      color: Color.statusSuccess)
                Divider().frame(height: 32)
                summaryCell(count: duplicateRows.count, label: "Existing", color: .secondary)
                Divider().frame(height: 32)
                summaryCell(count: errorRows.count,     label: "Invalid",  color: Color.statusError)
            }
            .padding(.vertical, 4)

            // Row previews (cap at 100 for performance)
            ForEach(parsedRows.prefix(100)) { row in rowCell(row) }
            if parsedRows.count > 100 {
                Text("…and \(parsedRows.count - 100) more rows not shown")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Preview — \(parsedRows.count) rows parsed")
        }
    }

    private var importSection: some View {
        Section {
            Button {
                Task { await doImport() }
            } label: {
                HStack {
                    Spacer()
                    if isImporting {
                        ProgressView().padding(.trailing, 8)
                        Text("Importing…")
                    } else {
                        Image(systemName: "square.and.arrow.down").padding(.trailing, 4)
                        Text("Import \(newRows.count) New Item\(newRows.count == 1 ? "" : "s")")
                    }
                    Spacer()
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.vertical, 4)
            }
            .listRowBackground(isImporting ? Color.gray : Color.brandDeepIndigo)
            .disabled(isImporting)
        } footer: {
            if !duplicateRows.isEmpty {
                Text("\(duplicateRows.count) existing item\(duplicateRows.count == 1 ? "" : "s") will be skipped.")
                    .font(.caption2)
            }
        }
    }

    private var resultSection: some View {
        Section {
            if let r = importResult {
                Label(
                    "Imported \(r.inserted) new item\(r.inserted == 1 ? "" : "s")",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(Color.statusSuccess)

                if r.skipped > 0 {
                    Label(
                        "Skipped \(r.skipped) existing item\(r.skipped == 1 ? "" : "s")",
                        systemImage: "arrow.trianglehead.counterclockwise"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Button("Refresh Equipment List") {
                    Task {
                        await vm.loadEquipment()
                        dismiss()
                    }
                }
                .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Row Cell

    private func rowCell(_ row: ParsedRow) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(row.isNew       ? Color.statusSuccess
                    : row.isDuplicate ? Color.secondary
                    :                   Color.statusError)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(row.equipmentId.isEmpty ? "(no ID)" : row.equipmentId)
                        .font(.caption.bold())
                        .foregroundStyle(row.isNew ? Color.brandDeepIndigo : .secondary)
                    if row.isDuplicate {
                        Text("exists")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                }
                if let err = row.error {
                    Text(err).font(.caption2).foregroundStyle(Color.statusError)
                } else {
                    Text(row.department).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 1)
    }

    private func summaryCell(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)").font(.title3.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Computed

    private var newRows:       [ParsedRow] { parsedRows.filter { $0.isNew        } }
    private var duplicateRows: [ParsedRow] { parsedRows.filter { $0.isDuplicate  } }
    private var errorRows:     [ParsedRow] { parsedRows.filter { !$0.isNew && !$0.isDuplicate } }

    // MARK: - File Handling

    private func handleFilePick(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let err):
            parseError = err.localizedDescription

        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                parseError = "Permission denied to read this file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            // Try UTF-8 first, fall back to Latin-1 for Excel exports
            guard let content = (try? String(contentsOf: url, encoding: .utf8))
                             ?? (try? String(contentsOf: url, encoding: .isoLatin1)) else {
                parseError = "Could not read the file — ensure it is a UTF-8 or Latin-1 encoded CSV."
                return
            }
            fileName = url.lastPathComponent
            parseContent(content)
        }
    }

    // MARK: - CSV Parsing

    private func parseContent(_ text: String) {
        let rows = splitCSV(text)

        guard rows.count >= 2 else {
            parseError = "File appears empty or contains only a header row."
            return
        }

        // Map header names → column index.
        // Normalise: lower-case, replace spaces with underscores so
        // "Equipment ID" and "equipment_id" both work.
        let headers = rows[0].map {
            $0.lowercased()
              .trimmingCharacters(in: .whitespaces)
              .replacingOccurrences(of: " ", with: "_")
        }
        func colIdx(_ name: String) -> Int? { headers.firstIndex(of: name) }

        let idxId   = colIdx("equipment_id")
        let idxDesc = colIdx("description")
        let idxDept = colIdx("department")
        let idxPfx  = colIdx("prefix")

        guard idxId != nil, idxDesc != nil, idxDept != nil else {
            let missing = [idxId == nil ? "equipment_id" : nil,
                           idxDesc == nil ? "description" : nil,
                           idxDept == nil ? "department"  : nil]
                          .compactMap { $0 }.joined(separator: ", ")
            parseError = "Missing required column(s): \(missing)"
            return
        }

        let idxEquipPhoto = colIdx("needs_equip_photo") ?? colIdx("needs_equipment_photo")
        let idxIsoPhoto   = colIdx("needs_iso_photo")   ?? colIdx("needs_isolation_photo")
        let idxNotes      = colIdx("notes")

        // Build set of known IDs for O(1) duplicate check
        let existingIDs = Set(vm.allEquipment.map { $0.equipmentId })

        parsedRows = rows.dropFirst().compactMap { cols in
            guard !cols.allSatisfy({ $0.isEmpty }) else { return nil }   // skip blank rows

            func val(_ idx: Int?) -> String? {
                guard let i = idx, i < cols.count else { return nil }
                let v = cols[i].trimmingCharacters(in: .whitespaces)
                return v.isEmpty ? nil : v
            }
            func boolVal(_ idx: Int?, default def: Bool = true) -> Bool {
                guard let raw = val(idx) else { return def }
                let lower = raw.lowercased()
                return lower == "true" || lower == "yes" || lower == "1"
            }

            let eqId = val(idxId)   ?? ""
            let desc = val(idxDesc) ?? ""
            let dept = val(idxDept) ?? ""
            // Derive prefix from equipment_id if column absent (e.g. "321-MX-01" → "321")
            let pfx  = val(idxPfx) ?? String(eqId.prefix(while: { $0 != "-" }))

            var err: String?
            if eqId.isEmpty  { err = "Missing equipment_id" }
            else if desc.isEmpty { err = "Missing description" }
            else if dept.isEmpty { err = "Missing department"  }

            return ParsedRow(
                equipmentId:     eqId,
                description:     desc,
                department:      dept,
                prefix:          pfx,
                needsEquipPhoto: boolVal(idxEquipPhoto),
                needsIsoPhoto:   boolVal(idxIsoPhoto),
                notes:           val(idxNotes),
                isDuplicate:     err == nil && existingIDs.contains(eqId),
                error:           err
            )
        }

        if parsedRows.isEmpty {
            parseError = "No valid data rows found in the file."
        } else {
            parseError = nil
        }
    }

    // MARK: - RFC 4180 CSV Splitter
    // Handles: quoted fields, commas inside quotes, escaped quotes (""),
    // Windows (\r\n), Unix (\n), and old Mac (\r) line endings.

    private func splitCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row:  [String]   = []
        var field = ""
        var quoted = false
        var i = text.startIndex

        while i < text.endIndex {
            let ch = text[i]
            let nx = text.index(after: i)

            if quoted {
                if ch == "\"" {
                    if nx < text.endIndex, text[nx] == "\"" {
                        field.append("\"")          // escaped "" inside quoted field
                        i = text.index(after: nx)
                        continue
                    }
                    quoted = false                  // closing quote
                } else {
                    field.append(ch)
                }
            } else {
                switch ch {
                case "\"":
                    quoted = true
                case ",":
                    row.append(field.trimmingCharacters(in: .whitespaces))
                    field = ""
                case "\r":
                    row.append(field.trimmingCharacters(in: .whitespaces))
                    field = ""
                    if !row.isEmpty { rows.append(row) }
                    row = []
                    if nx < text.endIndex, text[nx] == "\n" {   // consume \r\n as one newline
                        i = text.index(after: nx)
                        continue
                    }
                case "\n":
                    row.append(field.trimmingCharacters(in: .whitespaces))
                    field = ""
                    if !row.isEmpty { rows.append(row) }
                    row = []
                default:
                    field.append(ch)
                }
            }
            i = text.index(after: i)
        }
        // Flush last row
        if !field.isEmpty || !row.isEmpty {
            row.append(field.trimmingCharacters(in: .whitespaces))
            if !row.isEmpty { rows.append(row) }
        }
        return rows
    }

    // MARK: - Import

    private func doImport() async {
        let toInsert = newRows
        guard !toInsert.isEmpty else { return }
        isImporting = true
        defer { isImporting = false }

        let serviceRows = toInsert.map { row in
            SupabaseService.NewEquipmentRow(
                equipmentId:     row.equipmentId,
                description:     row.description,
                department:      row.department,
                prefix:          row.prefix,
                needsEquipPhoto: row.needsEquipPhoto,
                needsIsoPhoto:   row.needsIsoPhoto,
                notes:           row.notes
            )
        }

        do {
            let inserted = try await SupabaseService.shared.insertEquipment(serviceRows)
            importResult = ImportResult(inserted: inserted, skipped: duplicateRows.count)
        } catch {
            parseError = "Import failed: \((error as? SupabaseError)?.errorDescription ?? error.localizedDescription)"
        }
    }
}

#Preview {
    CSVImportView().environment(PlacardViewModel())
}

//
//  StatusReportView.swift
//  LOTO2Main
//
//  Generates and shares a LOTO placard status report PDF.
//

import SwiftUI

struct StatusReportView: View {

    @Environment(PlacardViewModel.self) private var vm
    @Environment(\.dismiss)            private var dismiss

    @State private var isGenerating = false
    @State private var reportURL:   URL?
    @State private var showShare    = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                summarySection
                if reportURL != nil  { shareSection  }
                if errorMessage != nil { errorSection }
                if reportURL == nil  { generateSection }
            }
            .navigationTitle("Status Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let url = reportURL { ShareSheet(url: url) }
        }
    }

    // MARK: - Sections

    private var summarySection: some View {
        Section {
            statRow(label: "Total Active",   value: vm.countActive,   color: Color.brandDeepIndigo)
            statRow(label: "Complete",       value: vm.countComplete, color: Color.statusSuccess)
            statRow(label: "Partial",        value: vm.countPartial,  color: Color.statusWarning)
            statRow(label: "Missing",        value: vm.countMissing,  color: Color.statusError)
            statRow(label: "Decommissioned", value: vm.allEquipment.count - vm.countActive, color: .secondary)
        } header: {
            Text("Current Status")
        } footer: {
            let pct = vm.countActive > 0
                ? Int(Double(vm.countComplete) / Double(vm.countActive) * 100)
                : 0
            Text("\(pct)% of active placards are complete.")
        }
    }

    private var generateSection: some View {
        Section {
            Button {
                Task { await generateReport() }
            } label: {
                HStack {
                    Spacer()
                    if isGenerating {
                        ProgressView().padding(.trailing, 8)
                        Text("Generating…")
                    } else {
                        Image(systemName: "doc.text.fill").padding(.trailing, 4)
                        Text("Generate PDF Report")
                    }
                    Spacer()
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.vertical, 4)
            }
            .listRowBackground(isGenerating ? Color.gray : Color.brandDeepIndigo)
            .disabled(isGenerating)
        } footer: {
            Text("Produces a multi-page PDF with overall stats, per-department breakdown, and a full equipment list.")
                .font(.caption2)
        }
    }

    private var shareSection: some View {
        Section {
            Button {
                showShare = true
            } label: {
                Label("Share / Save Report", systemImage: "square.and.arrow.up")
                    .foregroundStyle(Color.brandDeepIndigo)
                    .fontWeight(.semibold)
            }
            Button {
                reportURL = nil
                errorMessage = nil
            } label: {
                Label("Regenerate", systemImage: "arrow.clockwise")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Report Ready")
        }
    }

    private var errorSection: some View {
        Section {
            Label(errorMessage ?? "Unknown error", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.statusError)
                .font(.caption)
        }
    }

    // MARK: - Row Helper

    private func statRow(label: String, value: Int, color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(.primary)
            Spacer()
            Text("\(value)")
                .font(.headline.bold())
                .foregroundStyle(color)
        }
    }

    // MARK: - Generation

    private func generateReport() async {
        isGenerating  = true
        errorMessage  = nil
        defer { isGenerating = false }

        // Build deptPartialCounts on the fly (not cached in vm — compute once here)
        var deptPartial: [String: Int] = [:]
        let decommissioned = vm.decommissionedIDs
        for eq in vm.allEquipment where !decommissioned.contains(eq.equipmentId) {
            if eq.photoStatus == "partial" {
                deptPartial[eq.department, default: 0] += 1
            }
        }

        let reportData = StatusReportGenerator.ReportData(
            equipment:    vm.allEquipment,
            departments:  vm.departments,
            deptActive:   vm.deptActiveCounts,
            deptComplete: vm.deptCompleteCounts,
            signOffs:     vm.departmentSignOffs,
            decommissioned: decommissioned,
            countActive:  vm.countActive,
            countComplete: vm.countComplete,
            countPartial:  vm.countPartial,
            countMissing:  vm.countMissing
        )

        let pdfData = await Task.detached(priority: .userInitiated) {
            await MainActor.run { StatusReportGenerator.shared.generate(reportData) }
        }.value

        let fileName = "LOTO_Status_Report_\(filenameDateString()).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try pdfData.write(to: url, options: .atomic)
            reportURL = url
        } catch {
            errorMessage = "Could not write report file: \(error.localizedDescription)"
        }
    }

    private func filenameDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmm"
        return f.string(from: Date())
    }
}

#Preview {
    StatusReportView().environment(PlacardViewModel())
}

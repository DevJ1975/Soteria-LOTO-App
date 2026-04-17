//
//  BatchPrintView.swift
//  LOTO2Main
//
//  Select a department and generate a combined multi-page PDF
//  containing every LOTO placard in that department.
//  Useful for printing an entire department's set at once.
//

import SwiftUI
import PDFKit

struct BatchPrintView: View {

    @Environment(PlacardViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDepartment: String = ""
    @State private var isGenerating = false
    @State private var batchPDFURL: URL?
    @State private var showShare   = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                // Department picker
                Section("Select Department") {
                    if vm.departments.isEmpty {
                        Text("No departments loaded")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Department", selection: $selectedDepartment) {
                            Text("Select…").tag("")
                            ForEach(vm.departments, id: \.self) { dept in
                                Text(dept).tag(dept)
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                }

                // Info
                if !selectedDepartment.isEmpty {
                    Section("Batch Info") {
                        let count = vm.allEquipment.filter { $0.department == selectedDepartment }.count
                        LabeledContent("Equipment items", value: "\(count)")
                        LabeledContent("Output", value: "\(count)-page PDF")
                        LabeledContent("Note", value: "Photos must be taken individually per machine. Batch PDF uses placeholder photo slots.")
                    }
                }

                // Error
                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.statusError)
                    }
                }

                // Generate button
                Section {
                    Button {
                        Task { await generateBatch() }
                    } label: {
                        HStack {
                            Spacer()
                            if isGenerating {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Generating…")
                            } else {
                                Image(systemName: "doc.on.doc.fill")
                                    .padding(.trailing, 4)
                                Text("Generate Batch PDF")
                            }
                            Spacer()
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(
                        selectedDepartment.isEmpty || isGenerating
                            ? Color.gray : Color.brandDeepIndigo
                    )
                    .disabled(selectedDepartment.isEmpty || isGenerating)
                }
            }
            .navigationTitle("Batch Print by Department")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showShare) {
                if let url = batchPDFURL {
                    ShareSheet(url: url)
                }
            }
            .onAppear {
                selectedDepartment = vm.departments.first ?? ""
            }
        }
    }

    // MARK: - Batch Generation

    private func generateBatch() async {
        guard !selectedDepartment.isEmpty else { return }
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        let items = vm.allEquipment.filter { $0.department == selectedDepartment }
            .sorted { $0.equipmentId < $1.equipmentId }

        guard !items.isEmpty else {
            errorMessage = "No equipment found in this department."
            return
        }

        // Generate one PDF page per equipment item (no photos — batch mode)
        await MainActor.run {
            let combined = buildCombinedPDF(items: items)
            let name = "\(selectedDepartment)_LOTO_Batch.pdf"
                .replacingOccurrences(of: " ", with: "_")
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            if (try? combined.write(to: url)) != nil {
                batchPDFURL = url
                showShare   = true
            } else {
                errorMessage = "Could not write the PDF file."
            }
        }
    }

    @MainActor
    private func buildCombinedPDF(items: [Equipment]) -> Data {
        let pageSize = CGSize(width: 792, height: 612)
        let pageRect = CGRect(origin: .zero, size: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            for equipment in items {
                ctx.beginPage()

                // Generate each page as a UIImage (same approach as PDFGenerator.generate)
                // to guarantee correct orientation — no raw CGContext drawing.
                let pageData = PDFGenerator.shared.generate(
                    equipment: equipment,
                    equipmentPhoto: nil,
                    disconnectPhoto: nil
                )
                if let doc = PDFDocument(data: pageData),
                   let page = doc.page(at: 0) {
                    let b = page.bounds(for: .mediaBox)
                    let imgSize = CGSize(width: b.width, height: b.height)
                    let imgRenderer = UIGraphicsImageRenderer(size: imgSize)
                    let img = imgRenderer.image { imgCtx in
                        UIColor.white.setFill()
                        imgCtx.fill(CGRect(origin: .zero, size: imgSize))
                        imgCtx.cgContext.translateBy(x: 0, y: imgSize.height)
                        imgCtx.cgContext.scaleBy(x: 1, y: -1)
                        page.draw(with: .mediaBox, to: imgCtx.cgContext)
                    }
                    img.draw(in: pageRect)
                }
            }
        }
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

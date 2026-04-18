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
                        let deptItems  = vm.allEquipment.filter { $0.department == selectedDepartment }
                        let count      = deptItems.count
                        let withPhotos = deptItems.filter {
                            PhotoStorageService.shared.hasLocal(equipment: $0, type: .equipment) ||
                            PhotoStorageService.shared.hasLocal(equipment: $0, type: .isolation)
                        }.count
                        LabeledContent("Equipment items",  value: "\(count)")
                        LabeledContent("With local photos", value: "\(withPhotos) of \(count)")
                        LabeledContent("Output", value: "\(count)-page PDF with available photos")
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

    // MARK: - Batch Generation (#12 — includes locally-saved photos)

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

        // Pre-load local photos (fast index lookups, no network).
        var photoCache: [String: (UIImage?, UIImage?)] = [:]
        for item in items {
            let equip = PhotoStorageService.shared.loadLocal(equipment: item, type: .equipment)
            let iso   = PhotoStorageService.shared.loadLocal(equipment: item, type: .isolation)
            if equip != nil || iso != nil {
                photoCache[item.equipmentId] = (equip, iso)
            }
        }

        // Generate all page images on a background thread so the main thread
        // stays free (large departments can take several seconds to render).
        let combined = await Task.detached(priority: .userInitiated) {
            await buildCombinedPDF(items: items, photoCache: photoCache)
        }.value

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

    // PDFGenerator is @MainActor, so each page hops to main; the outer Task is
    // detached to prevent the call-site from blocking the SwiftUI render loop.
    @MainActor
    private func buildCombinedPDF(items: [Equipment],
                                   photoCache: [String: (UIImage?, UIImage?)]) -> Data {
        let pageSize = CGSize(width: 792, height: 612)
        let pageRect = CGRect(origin: .zero, size: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            for equipment in items {
                ctx.beginPage()
                let (equip, iso) = photoCache[equipment.equipmentId] ?? (nil, nil)
                let pageData = PDFGenerator.shared.generate(
                    equipment: equipment,
                    equipmentPhoto: equip,
                    disconnectPhoto: iso
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

//
//  PlacardPreviewView.swift
//  LOTO2Main
//
//  Displays the generated PDF placard and provides options to
//  share (AirDrop, Files, print) or upload photos to Supabase.
//

import SwiftUI
import PDFKit

struct PlacardPreviewView: View {

    @Environment(PlacardViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var showUploadError = false
    @State private var pdfShareURL: URL?   // cached once on appear; avoids disk write on every render

    var body: some View {
        NavigationStack {
            Group {
                if let pdfData = vm.generatedPDFData {
                    PDFKitView(data: pdfData)
                        .ignoresSafeArea(edges: .bottom)
                } else if let error = vm.pdfError {
                    errorView(error)
                } else {
                    generatingView
                }
            }
            .navigationTitle("Placard Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { navToolbar }
            .onAppear {
                // Write PDF to temp once on appear — ShareLink must not do this per render.
                if let data = vm.generatedPDFData { pdfShareURL = makeShareURL(data: data) }
            }
            .alert("Upload Failed", isPresented: $showUploadError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.uploadError ?? "Upload failed. Photos saved locally and queued for your next manual sync.")
            }
        }
    }

    // MARK: - Generating Spinner

    private var generatingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Generating PDF…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.statusError)
            Text("PDF generation failed")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandDeepIndigo)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var navToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Done") { dismiss() }
        }

        ToolbarItem(placement: .topBarTrailing) {
            if let url = pdfShareURL {
                ShareLink(
                    item: url,
                    preview: SharePreview(
                        "LOTO Placard — \(vm.selectedEquipment?.equipmentId ?? "")",
                        image: Image(systemName: "doc.fill")
                    )
                ) {
                    Label("Share / Print", systemImage: "square.and.arrow.up")
                }
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task {
                    await vm.uploadPhotosAndSave()
                    if vm.uploadError != nil {
                        showUploadError = true
                    } else {
                        UINotificationFeedbackGenerator().notificationOccurred(
                            vm.savedOffline ? .warning : .success
                        )
                    }
                }
            } label: {
                if vm.isUploading {
                    ProgressView().scaleEffect(0.8)
                } else if vm.savedOffline {
                    Label("Saved Offline", systemImage: "icloud.slash")
                        .foregroundStyle(Color.statusWarning)
                } else {
                    Label("Save Photos", systemImage: "icloud.and.arrow.up")
                }
            }
            // Matches PlacardFormView — also allow PDF-only uploads when no session photos
            .disabled(
                vm.isUploading ||
                (vm.equipmentPhoto == nil && vm.disconnectPhoto == nil && vm.generatedPDFData == nil)
            )
        }
    }

    // MARK: - Helpers

    /// Writes the PDF to a temp file once and returns the URL.
    /// Called from .onAppear — NOT from the toolbar/view body — so the disk
    /// write doesn't repeat on every SwiftUI re-render.
    private func makeShareURL(data: Data) -> URL? {
        let id   = vm.selectedEquipment?.equipmentId ?? "placard"
        let name = "\(id)_LOTO_Placard.pdf"
        let url  = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        guard (try? data.write(to: url)) != nil else { return nil }
        return url
    }
}

// MARK: - PDFKitView

/// SwiftUI wrapper around PDFKit's PDFView for displaying a rendered PDF.
struct PDFKitView: UIViewRepresentable {

    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView        = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document  = PDFDocument(data: data)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // PDFDocument(data:) is expensive — only set once; data never changes within this view.
        guard pdfView.document == nil else { return }
        pdfView.document = PDFDocument(data: data)
    }
}

//
//  PlacardFormView.swift
//  LOTO2Main
//
//  In-app form styled to visually match the Snak King LOTO placard.
//  Pre-fills all data from Supabase. User taps photo slots to capture
//  equipment + isolation point photos via camera or photo library,
//  then generates the PDF.
//

import SwiftUI
import PhotosUI

struct PlacardFormView: View {

    let equipment: Equipment
    let onClose: () -> Void
    @Environment(PlacardViewModel.self) private var vm

    // Library picker state
    @State private var showEquipPicker   = false
    @State private var showIsoPicker     = false
    @State private var equipPickerItem:  PhotosPickerItem?
    @State private var isoPickerItem:    PhotosPickerItem?

    // Camera state
    @State private var showEquipCamera   = false
    @State private var showIsoCamera     = false

    // Re-shoot confirmation
    @State private var reshootTarget:    PhotoTarget? = nil

    // Preview sheet
    @State private var showPreview       = false

    // Spanish editing sheet
    @State private var showSpanishEdit   = false

    // Upload feedback
    @State private var uploadSucceeded   = false
    @State private var showUploadError   = false
    @State private var checkmarkScale:   CGFloat = 0
    @State private var spinDegrees:      Double  = 0

    private enum PhotoTarget { case equipment, isolation }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerBand
                    // Compact photo thumbnails for quick reference (#11)
                    if vm.equipmentPhoto != nil || vm.disconnectPhoto != nil
                        || vm.existingEquipPhoto != nil || vm.existingIsoPhoto != nil {
                        photoThumbnailStrip
                    }
                    equipmentBar
                    warningBlock
                    purposeAndSteps
                    colorCodeBar
                    energySectionHeader
                    energyIsolationSection
                    signatureBar
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { navToolbar }
            .sheet(isPresented: $showPreview) {
                PlacardPreviewView().environment(vm)
            }
            .sheet(isPresented: $showSpanishEdit) {
                SpanishEditSheet(equipment: equipment).environment(vm)
            }
            .sheet(isPresented: $showEquipCamera) {
                CameraPickerView { image in
                    vm.photoTaken(image, type: .equipment)
                }
            }
            .sheet(isPresented: $showIsoCamera) {
                CameraPickerView { image in
                    vm.photoTaken(image, type: .isolation)
                }
            }
            .onChange(of: equipPickerItem) { _, item in
                Task { await loadPhoto(item: item, type: .equipment) }
            }
            .onChange(of: isoPickerItem) { _, item in
                Task { await loadPhoto(item: item, type: .isolation) }
            }
            .confirmationDialog(
                "A photo already exists for this equipment. Replace it?",
                isPresented: Binding(
                    get: { reshootTarget != nil },
                    set: { if !$0 { reshootTarget = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Take New Photo") {
                    if reshootTarget == .equipment { showEquipCamera = true }
                    else { showIsoCamera = true }
                    reshootTarget = nil
                }
                Button("Choose from Library") {
                    if reshootTarget == .equipment { showEquipPicker = true }
                    else { showIsoPicker = true }
                    reshootTarget = nil
                }
                Button("Cancel", role: .cancel) { reshootTarget = nil }
            }
        }
        .overlay {
            if vm.isUploading {
                uploadProgressOverlay
                    .transition(.opacity)
            }
        }
        .overlay {
            if uploadSucceeded {
                uploadSuccessOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.isUploading)
        .animation(.easeInOut(duration: 0.2), value: uploadSucceeded)
        .tint(Color.brandDeepIndigo)
    }

    // MARK: - Upload Progress Overlay

    private var uploadProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 24) {
                // Spinning arc ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 6)
                        .frame(width: 72, height: 72)
                    Circle()
                        .trim(from: 0, to: 0.65)
                        .stroke(Color.white,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(spinDegrees))
                        .onAppear {
                            spinDegrees = 0
                            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                                spinDegrees = 360
                            }
                        }
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.title2)
                        .foregroundStyle(.white)
                }

                VStack(spacing: 6) {
                    Text("Uploading Placard")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(vm.uploadStep)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .animation(.default, value: vm.uploadStep)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 36)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.4), radius: 24)
        }
    }

    // MARK: - Upload Success Overlay

    private var uploadSuccessOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)
                    .scaleEffect(checkmarkScale)
                    .onAppear {
                        checkmarkScale = 0
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                            checkmarkScale = 1.0
                        }
                    }
                Text("Upload Complete")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Photos synced to Supabase")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 36)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.4), radius: 24)
        }
    }

    // MARK: - Header Band (yellow)

    private var headerBand: some View {
        HStack(spacing: 0) {
            Image("SnakKingLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 40)
                .padding(.horizontal, 4)

            Divider().frame(height: 44)

            Text("LOCKOUT/TAGOUT PROCEDURE")
                .font(.system(size: 14, weight: .black)).foregroundStyle(.black)
                .frame(maxWidth: .infinity)

            Divider().frame(height: 44)

            Text(formattedDate())
                .font(.system(size: 9)).foregroundStyle(.black)
                .frame(width: 80).multilineTextAlignment(.center)
        }
        .frame(height: 44)
        .background(Color(red: 1, green: 0.85, blue: 0))
        .overlay(Rectangle().strokeBorder(.black, lineWidth: 1))
    }

    // MARK: - Photo Thumbnail Strip (#11)

    private var photoThumbnailStrip: some View {
        HStack(spacing: 8) {
            if let img = vm.equipmentPhoto ?? vm.existingEquipPhoto {
                VStack(spacing: 2) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 48, height: 36).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text("EQUIP").font(.system(size: 6, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                }
            }
            if let img = vm.disconnectPhoto ?? vm.existingIsoPhoto {
                VStack(spacing: 2) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 48, height: 36).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text("ISO").font(.system(size: 6, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                }
            }
            Spacer()
            Image(systemName: "photo.stack.fill")
                .font(.caption2).foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Color(red: 0.13, green: 0.22, blue: 0.48))
    }

    // MARK: - Equipment Bar

    private var equipmentBar: some View {
        HStack {
            Text("EQUIPMENT:")
                .font(.system(size: 9, weight: .bold))
            Text(equipment.description)
                .font(.system(size: 9))
                .lineLimit(1)
            Spacer()
            Text(equipment.department)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.brandDeepIndigo)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color(red: 0.85, green: 0.92, blue: 1))
        .overlay(Rectangle().strokeBorder(.black, lineWidth: 0.5))
    }

    // MARK: - Warning Block (red)

    private var warningBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("KEEP OUT! HAZARDOUS VOLTAGE AND MOVING PARTS.")
                .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
            Text(equipment.notes.flatMap { $0.isEmpty ? nil : $0 } ?? "Refer to the physical LOTO placard on this equipment for full hazard and energy isolation details.")
                .font(.system(size: 8)).foregroundStyle(.white)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.75, green: 0.08, blue: 0.08))
        .overlay(Rectangle().strokeBorder(.black, lineWidth: 0.5))
    }

    // MARK: - Purpose + Steps

    private var purposeAndSteps: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(standardPurpose)
                .font(.system(size: 7.5))
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 3) {
                Text("LOCKOUT APPLICATION PROCESS")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.brandDeepIndigo)
                ForEach(Array(applicationSteps.enumerated()), id: \.offset) { _, step in
                    Text(step).font(.system(size: 7.5))
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.white)
        .overlay(Rectangle().strokeBorder(.black.opacity(0.3), lineWidth: 0.5))
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Color Code Legend

    private var colorCodeBar: some View {
        HStack(spacing: 0) {
            ForEach(EnergyCode.all, id: \.code) { ec in
                Text("\(ec.code) = \(ec.labelEn)")
                    .font(.system(size: 7, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 3)
        .background(Color(UIColor.systemGray5))
        .overlay(Rectangle().strokeBorder(.black.opacity(0.3), lineWidth: 0.5))
    }

    // MARK: - Section Header (navy)

    private var energySectionHeader: some View {
        Text("EQUIPMENT IDENTIFICATION AND ENERGY ISOLATION PROCEDURE")
            .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 5)
            .background(Color(red: 0.13, green: 0.27, blue: 0.53))
    }

    // MARK: - Energy + Photo Section

    private var energyIsolationSection: some View {
        VStack(spacing: 0) {
            // Photos side by side across the top (matches physical placard layout)
            photoRow
            Divider()
            energyTable
        }
        .background(.white)
        .overlay(Rectangle().strokeBorder(.black.opacity(0.4), lineWidth: 0.5))
    }

    // MARK: - Photo Row (side by side)

    private var photoRow: some View {
        HStack(spacing: 0) {
            photoSlot(
                newImage: vm.equipmentPhoto,
                existingImage: vm.existingEquipPhoto,
                label: "Photo of Equipment",
                systemIcon: "camera.fill",
                hasUploaded: equipment.equipPhotoUrl != nil,
                target: .equipment
            )
            .photosPicker(isPresented: $showEquipPicker,
                          selection: $equipPickerItem,
                          matching: .images)
            .frame(maxWidth: .infinity)

            Divider()

            photoSlot(
                newImage: vm.disconnectPhoto,
                existingImage: vm.existingIsoPhoto,
                label: "Photo of Isolation / Disconnect",
                systemIcon: "bolt.slash.fill",
                hasUploaded: equipment.isoPhotoUrl != nil,
                target: .isolation
            )
            .photosPicker(isPresented: $showIsoPicker,
                          selection: $isoPickerItem,
                          matching: .images)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 170)
    }

    private func photoSlot(newImage: UIImage?, existingImage: UIImage?,
                            label: String, systemIcon: String,
                            hasUploaded: Bool, target: PhotoTarget) -> some View {
        // Display priority: newly captured > previously uploaded > placeholder
        let displayImage = newImage ?? existingImage

        return Button {
            if hasUploaded && newImage == nil {
                // Already has an uploaded photo — confirm before replacing
                reshootTarget = target
            } else {
                if target == .equipment { showEquipCamera = true }
                else { showIsoCamera = true }
            }
        } label: {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    if let img = displayImage {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(height: 130).clipped()
                    } else if vm.isLoadingExistingPhotos {
                        Color(UIColor.systemGray6).frame(height: 130)
                            .overlay(ProgressView())
                    } else {
                        ZStack {
                            Color(UIColor.systemGray6).frame(height: 130)
                            VStack(spacing: 6) {
                                Image(systemName: systemIcon)
                                    .font(.title2).foregroundStyle(Color.brandDeepIndigo.opacity(0.7))
                                Text("Tap to photograph")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Upload status badge (top-right corner of photo)
                    let isUploading = target == .equipment ? vm.isUploadingEquipPhoto : vm.isUploadingIsoPhoto
                    let uploaded    = target == .equipment ? vm.equipPhotoUploaded    : vm.isoPhotoUploaded

                    Group {
                        if isUploading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .padding(6)
                                .background(.ultraThinMaterial, in: Circle())
                                .padding(4)
                        } else if uploaded {
                            Image(systemName: "checkmark.icloud.fill")
                                .font(.caption).foregroundStyle(Color.statusSuccess)
                                .padding(6)
                                .background(.ultraThinMaterial, in: Circle())
                                .padding(4)
                        } else if newImage != nil {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.caption).foregroundStyle(Color.statusWarning)
                                .padding(6)
                                .background(.ultraThinMaterial, in: Circle())
                                .padding(4)
                        } else if existingImage != nil {
                            Image(systemName: "checkmark.icloud.fill")
                                .font(.caption).foregroundStyle(Color.statusSuccess)
                                .padding(6)
                        }
                    }
                }

                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 4)
            }
        }
        .buttonStyle(.plain)
        // Long press always allows camera or library without warning
        .contextMenu {
            Button { if target == .equipment { showEquipCamera = true } else { showIsoCamera = true } } label: {
                Label("Take New Photo", systemImage: "camera")
            }
            Button { if target == .equipment { showEquipPicker = true } else { showIsoPicker = true } } label: {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
            }
        }
    }

    // MARK: - Energy Table

    private var energyTable: some View {
        VStack(spacing: 0) {
            // Column headers
            HStack(spacing: 0) {
                tableHeader("Energy Tag & Description")
                Divider()
                tableHeader("Isolation Procedure & Lockout Devices")
                Divider()
                tableHeader("Method of Verification")
            }
            .background(Color(red: 0.25, green: 0.35, blue: 0.6))
            .frame(height: 28)

            if vm.isLoadingSteps {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 24)
            } else if vm.energySteps.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title).foregroundStyle(Color.brandDeepIndigo.opacity(0.4))
                    Text("Energy isolation steps will appear here once imported into Supabase.")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(vm.energySteps) { step in
                    energyStepRow(step)
                    Divider()
                }
            }
        }
    }

    private func energyStepRow(_ step: EnergyStep) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Energy type badge + description
            HStack(alignment: .top, spacing: 6) {
                Text(step.energyType)
                    .font(.system(size: 8, weight: .black))
                    .frame(width: 20)
                    .padding(.top, 2)
                    .foregroundStyle(energyTypeColor(step.energyType))
                Text(step.tagDescription ?? "")
                    .font(.system(size: 7.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(5)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            Text(step.isolationProcedure ?? "")
                .font(.system(size: 7.5))
                .padding(5)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            Text(step.methodOfVerification ?? "")
                .font(.system(size: 7.5))
                .padding(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func energyTypeColor(_ type: String) -> Color {
        EnergyCode.forType(type)?.color ?? Color.brandDeepIndigo
    }

    private func tableHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 7.5, weight: .bold)).foregroundStyle(.white)
            .padding(5).frame(maxWidth: .infinity).multilineTextAlignment(.center)
    }

    // MARK: - Signature Bar

    private var signatureBar: some View {
        HStack(spacing: 0) {
            ForEach(["Signature: _______________", "Date: _______________",
                     "Dept: _______________", "See PM Store in PT Folder"], id: \.self) { l in
                Text(l).font(.system(size: 7)).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
        }
        .background(Color(UIColor.systemGray6))
        .overlay(Rectangle().strokeBorder(.black.opacity(0.3), lineWidth: 0.5))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var navToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) { Button("Close") { onClose() } }

        // Next equipment in the current filtered list
        if let next = vm.nextEquipment {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    vm.select(next)
                } label: {
                    Label(next.equipmentId, systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                        .font(.caption.bold())
                }
            }
        }

        // Upload button — manual sync
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                uploadSucceeded = false
                checkmarkScale  = 0
                showUploadError = false
                Task {
                    await vm.uploadPhotosAndSave()
                    if vm.uploadError != nil {
                        showUploadError = true
                    } else if !vm.savedOffline {
                        uploadSucceeded = true
                        try? await Task.sleep(for: .seconds(2.5))
                        uploadSucceeded = false
                    }
                }
            } label: {
                if vm.isUploading {
                    ProgressView().scaleEffect(0.8)
                } else if uploadSucceeded {
                    Label("Uploaded", systemImage: "checkmark.icloud.fill")
                        .foregroundStyle(.green)
                } else if vm.savedOffline {
                    Label("Queued", systemImage: "icloud.slash")
                        .foregroundStyle(.orange)
                } else {
                    Label("Upload", systemImage: "icloud.and.arrow.up")
                }
            }
            .disabled(
                vm.isUploading ||
                (vm.equipmentPhoto == nil && vm.disconnectPhoto == nil &&
                 vm.existingEquipPhoto == nil && vm.existingIsoPhoto == nil)
            )
            .alert("Upload Failed", isPresented: $showUploadError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.uploadError ?? "An unknown error occurred. The photos have been queued for your next upload attempt.")
            }
        }

        // Spanish translation button
        ToolbarItem(placement: .topBarTrailing) {
            Button { showSpanishEdit = true } label: {
                Label("Español", systemImage: equipment.spanishReviewed
                      ? "checkmark.circle.fill" : "globe")
                    .foregroundStyle(equipment.spanishReviewed ? .green : .primary)
            }
            .disabled(vm.isLoadingSteps && vm.energySteps.isEmpty)
        }

        // Generate PDF button
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task {
                    await vm.generatePDF()
                    showPreview = true
                }
            } label: {
                if vm.isGeneratingPDF {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Label("PDF", systemImage: "doc.badge.plus")
                }
            }
            .disabled(vm.isGeneratingPDF || (vm.equipmentPhoto == nil && vm.disconnectPhoto == nil
                && vm.existingEquipPhoto == nil && vm.existingIsoPhoto == nil))
        }
    }

    // MARK: - Photo Loading

    private func loadPhoto(item: PhotosPickerItem?, type: LOTOPhotoType) async {
        guard let item else { return }
        if let data  = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            vm.photoTaken(image, type: type)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
    }()

    private func formattedDate() -> String {
        Self.dateFormatter.string(from: Date())
    }

    // MARK: - Static Text

    private let applicationSteps = [
        "1. Communicate to AFFECTED employees.",
        "2. Shut down equipment using normal stopping procedures.",
        "3. Isolate energy sources.",
        "4. Apply lockout devices, locks, and tags.",
        "5. Follow all steps in the isolation procedure.",
        "6. Verify equipment is de-energized by attempting to start up.",
        "7. After test, place controls in a neutral position.",
    ]

    private let standardPurpose = """
The purpose of this procedure is to establish mandatory requirements for the Control of Hazardous Energy at the Snak King facility in compliance with Cal/OSHA Title 8 §3314. This placard provides specific, standardized instructions to ensure that this equipment is isolated from all electrical, hydraulic, pneumatic, and gravity energy sources before any employee performs maintenance, cleaning, or clearing of jams. All employees must strictly adhere to these limitations.
"""

}

// MARK: - SpanishStepDraft (local editing state)

private struct SpanishStepDraft {
    var tagDescriptionEs: String = ""
    var isolationProcedureEs: String = ""
    var methodOfVerificationEs: String = ""
}

// MARK: - SpanishEditSheet

private struct SpanishEditSheet: View {

    let equipment: Equipment
    @Environment(PlacardViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var notesEsDraft:         String = ""
    @State private var spanishReviewedDraft: Bool   = false
    @State private var stepDrafts:           [UUID: SpanishStepDraft] = [:]
    @State private var isSaving:             Bool   = false
    @State private var saveError:            String? = nil

    var body: some View {
        NavigationStack {
            Form {
                // Warning / Notes (Spanish)
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Advertencia / Notas")
                            .font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: $notesEsDraft)
                            .frame(minHeight: 72)
                    }
                } header: {
                    Text("Bloque de Advertencia")
                } footer: {
                    Text("Aparece en el bloque rojo de la placa. Si está vacío, se muestra el texto predeterminado en español.")
                        .font(.caption2)
                }

                // Reviewed toggle
                Section {
                    Toggle(isOn: $spanishReviewedDraft) {
                        Label("Traducción revisada",
                              systemImage: spanishReviewedDraft ? "checkmark.seal.fill" : "checkmark.seal")
                            .foregroundStyle(spanishReviewedDraft ? .green : .primary)
                    }
                } footer: {
                    Text("Marcar como revisada elimina la marca de agua \"BORRADOR\" de la página en español del PDF.")
                        .font(.caption2)
                }

                // Energy step translations
                if !vm.energySteps.isEmpty {
                    ForEach(vm.energySteps) { step in
                        let ec = EnergyCode.forType(step.energyType)
                        Section {
                            stepField("Etiqueta / Descripción",
                                      binding: tagBinding(step.id),
                                      placeholder: step.tagDescription ?? "")
                            stepField("Procedimiento de Aislamiento",
                                      binding: isoBinding(step.id),
                                      placeholder: step.isolationProcedure ?? "")
                            stepField("Método de Verificación",
                                      binding: verBinding(step.id),
                                      placeholder: step.methodOfVerification ?? "")
                        } header: {
                            HStack(spacing: 6) {
                                Text(step.energyType)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(ec?.color ?? Color.secondary, in: RoundedRectangle(cornerRadius: 4))
                                    .foregroundStyle(.white)
                                Text("Paso \(step.stepNumber)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                } else if vm.isLoadingSteps {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Cargando pasos de energía…").foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Section {
                        Text("No hay pasos de energía cargados para este equipo.")
                            .foregroundStyle(.secondary).font(.caption)
                    }
                }
            }
            .navigationTitle("Traducción al Español")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView().scaleEffect(0.8) }
                        else        { Text("Guardar").bold() }
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Error al guardar", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
        .onAppear { populate() }
    }

    // MARK: - Step field helper

    @ViewBuilder
    private func stepField(_ label: String, binding: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            TextField(placeholder.isEmpty ? "(vacío)" : placeholder,
                      text: binding, axis: .vertical)
                .lineLimit(2...)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Bindings into stepDrafts dict

    private func tagBinding(_ id: UUID) -> Binding<String> {
        Binding(get: { stepDrafts[id]?.tagDescriptionEs ?? "" },
                set: { stepDrafts[id, default: SpanishStepDraft()].tagDescriptionEs = $0 })
    }
    private func isoBinding(_ id: UUID) -> Binding<String> {
        Binding(get: { stepDrafts[id]?.isolationProcedureEs ?? "" },
                set: { stepDrafts[id, default: SpanishStepDraft()].isolationProcedureEs = $0 })
    }
    private func verBinding(_ id: UUID) -> Binding<String> {
        Binding(get: { stepDrafts[id]?.methodOfVerificationEs ?? "" },
                set: { stepDrafts[id, default: SpanishStepDraft()].methodOfVerificationEs = $0 })
    }

    // MARK: - Populate from live data

    private func populate() {
        notesEsDraft         = equipment.notesEs ?? ""
        spanishReviewedDraft = equipment.spanishReviewed
        for step in vm.energySteps {
            stepDrafts[step.id] = SpanishStepDraft(
                tagDescriptionEs:         step.tagDescriptionEs         ?? "",
                isolationProcedureEs:     step.isolationProcedureEs     ?? "",
                methodOfVerificationEs:   step.methodOfVerificationEs   ?? ""
            )
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let edits = vm.energySteps.map { step in
            let d = stepDrafts[step.id]
            return PlacardViewModel.SpanishStepEdit(
                stepId:               step.id,
                tagDescriptionEs:     d?.tagDescriptionEs.nonEmpty,
                isolationProcedureEs: d?.isolationProcedureEs.nonEmpty,
                methodOfVerificationEs: d?.methodOfVerificationEs.nonEmpty
            )
        }

        let ok = await vm.saveSpanishTranslations(
            equipment:       equipment,
            notesEs:         notesEsDraft.nonEmpty,
            spanishReviewed: spanishReviewedDraft,
            stepEdits:       edits
        )

        if ok { dismiss() } else { saveError = vm.spanishSaveError ?? "Error desconocido." }
    }
}

// MARK: - String.nonEmpty helper

private extension String {
    /// Returns nil if the string is empty, otherwise self.
    var nonEmpty: String? { isEmpty ? nil : self }
}

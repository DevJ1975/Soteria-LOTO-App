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
    @Environment(PlacardViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    // Library picker state
    @State private var showEquipPicker   = false
    @State private var showIsoPicker     = false
    @State private var equipPickerItem:  PhotosPickerItem?
    @State private var isoPickerItem:    PhotosPickerItem?

    // Camera state
    @State private var showEquipCamera   = false
    @State private var showIsoCamera     = false

    // Preview sheet
    @State private var showPreview       = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerBand
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
            .sheet(isPresented: $showEquipCamera) {
                CameraPickerView { image in
                    vm.equipmentPhoto = image
                }
            }
            .sheet(isPresented: $showIsoCamera) {
                CameraPickerView { image in
                    vm.disconnectPhoto = image
                }
            }
            .onChange(of: equipPickerItem) { _, item in
                Task { await loadPhoto(item: item, isEquipment: true) }
            }
            .onChange(of: isoPickerItem) { _, item in
                Task { await loadPhoto(item: item, isEquipment: false) }
            }
        }
        .tint(Color.brandDeepIndigo)
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
            Text(equipment.notes ?? "Refer to the physical LOTO placard on this equipment for full hazard and energy isolation details.")
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
            ForEach(energyCodes, id: \.0) { code, label in
                Text("\(code) = \(label)")
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
                image: vm.equipmentPhoto,
                label: "Photo of Equipment",
                systemIcon: "camera.fill",
                onCamera: { showEquipCamera = true },
                onLibrary: { showEquipPicker = true }
            )
            .photosPicker(isPresented: $showEquipPicker,
                          selection: $equipPickerItem,
                          matching: .images)
            .frame(maxWidth: .infinity)

            Divider()

            photoSlot(
                image: vm.disconnectPhoto,
                label: "Photo of Isolation / Disconnect",
                systemIcon: "bolt.slash.fill",
                onCamera: { showIsoCamera = true },
                onLibrary: { showIsoPicker = true }
            )
            .photosPicker(isPresented: $showIsoPicker,
                          selection: $isoPickerItem,
                          matching: .images)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 160)
    }

    private func photoSlot(image: UIImage?, label: String, systemIcon: String,
                            onCamera: @escaping () -> Void, onLibrary: @escaping () -> Void) -> some View {
        Menu {
            Button { onCamera() } label: {
                Label("Take Photo", systemImage: "camera")
            }
            Button { onLibrary() } label: {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
            }
        } label: {
            VStack(spacing: 6) {
                if let img = image {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(height: 120).clipped()
                } else {
                    ZStack {
                        Color(UIColor.systemGray6).frame(height: 120)
                        VStack(spacing: 6) {
                            Image(systemName: systemIcon)
                                .font(.title2).foregroundStyle(Color.brandDeepIndigo.opacity(0.7))
                            Text("Tap to photograph")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 4)
            }
        }
        .buttonStyle(.plain)
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
        switch type {
        case "E":  return Color(red: 1, green: 0.85, blue: 0)    // yellow (electrical)
        case "H":  return Color(red: 0.08, green: 0.47, blue: 0.78) // blue (hydraulic)
        case "P":  return Color(red: 0.6, green: 0.6, blue: 0.6)  // gray (pneumatic)
        case "G":  return Color(red: 0.2, green: 0.6, blue: 0.2)  // green (gas)
        case "M":  return Color(red: 0.75, green: 0.08, blue: 0.08) // red (mechanical)
        default:   return Color.brandDeepIndigo
        }
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
        ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task { await vm.generatePDF(); showPreview = true }
            } label: {
                if vm.isGeneratingPDF {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Label("Generate PDF", systemImage: "doc.badge.plus")
                }
            }
            .disabled(vm.isGeneratingPDF || (vm.equipmentPhoto == nil && vm.disconnectPhoto == nil))
        }
    }

    // MARK: - Photo Loading

    private func loadPhoto(item: PhotosPickerItem?, isEquipment: Bool) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            if isEquipment { vm.equipmentPhoto    = image }
            else           { vm.disconnectPhoto   = image }
        }
    }

    private func formattedDate() -> String {
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: Date())
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

    private let energyCodes: [(String, String)] = [
        ("E","Electrical"),("G","Gas"),("H","Hydraulic"),
        ("P","Pneumatic"),("N","None"),("O","Mechanical"),("OG","Comp. Gas")
    ]
}

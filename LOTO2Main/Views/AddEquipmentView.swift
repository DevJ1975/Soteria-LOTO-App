//
//  AddEquipmentView.swift
//  LOTO2Main
//
//  Form to add a single new equipment item directly to Supabase.
//  Duplicate equipment_id values are caught locally before any network call.
//

import SwiftUI

struct AddEquipmentView: View {

    @Environment(PlacardViewModel.self) private var vm
    @Environment(\.dismiss)            private var dismiss

    // Form fields
    @State private var equipmentId     = ""
    @State private var description     = ""
    @State private var department      = ""
    @State private var prefix          = ""
    @State private var needsEquipPhoto = true
    @State private var needsIsoPhoto   = true
    @State private var notes           = ""

    // UI state
    @State private var isSaving        = false
    @State private var saveError:     String? = nil
    @State private var idError:       String? = nil   // inline duplicate warning

    // Department picker — existing departments + "New…" option
    @State private var useNewDept      = false
    @State private var newDeptName     = ""

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                departmentSection
                photoSection
                notesSection
                if let err = saveError { errorSection(err) }
                saveSection
            }
            .navigationTitle("Add Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .disabled(isSaving)
        }
    }

    // MARK: - Sections

    private var identitySection: some View {
        Section {
            LabeledContent("Equipment ID") {
                TextField("e.g. 321-MX-01", text: $equipmentId)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .onChange(of: equipmentId) { _, new in
                        validateID(new)
                        // Auto-derive prefix from everything before the first "-"
                        let derived = String(new.prefix(while: { $0 != "-" }))
                        if !derived.isEmpty { prefix = derived }
                    }
            }
            if let err = idError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.statusError)
            }
            LabeledContent("Description") {
                TextField("Full machine description", text: $description)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
            }
            LabeledContent("Prefix") {
                TextField("e.g. 321", text: $prefix)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
            }
        } header: {
            Text("Identity")
        } footer: {
            Text("Prefix is auto-derived from the Equipment ID. Edit if needed.")
                .font(.caption2)
        }
    }

    private var departmentSection: some View {
        Section("Department") {
            if vm.departments.isEmpty || useNewDept {
                HStack {
                    TextField("New department name", text: $newDeptName)
                        .autocorrectionDisabled()
                    if !vm.departments.isEmpty {
                        Button("Pick existing") { useNewDept = false }
                            .font(.caption)
                            .foregroundStyle(Color.brandDeepIndigo)
                    }
                }
            } else {
                Picker("Department", selection: $department) {
                    ForEach(vm.departments, id: \.self) { dept in
                        Text(dept).tag(dept)
                    }
                }
                .pickerStyle(.menu)
                .onAppear {
                    if department.isEmpty, let first = vm.departments.first {
                        department = first
                    }
                }
                Button("Add new department…") { useNewDept = true }
                    .font(.subheadline)
                    .foregroundStyle(Color.brandDeepIndigo)
            }
        }
    }

    private var photoSection: some View {
        Section {
            Toggle("Needs Equipment Photo", isOn: $needsEquipPhoto)
            Toggle("Needs Isolation Photo", isOn: $needsIsoPhoto)
        } header: {
            Text("Photo Requirements")
        } footer: {
            Text("Disable for equipment that only requires one photo type or no photos.")
                .font(.caption2)
        }
    }

    private var notesSection: some View {
        Section("Notes (optional)") {
            TextField("Any relevant notes…", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private func errorSection(_ message: String) -> some View {
        Section {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.statusError)
                .font(.caption)
        }
    }

    private var saveSection: some View {
        Section {
            Button {
                Task { await save() }
            } label: {
                HStack {
                    Spacer()
                    if isSaving {
                        ProgressView().padding(.trailing, 8)
                        Text("Saving…")
                    } else {
                        Image(systemName: "plus.circle.fill").padding(.trailing, 4)
                        Text("Add Equipment")
                    }
                    Spacer()
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.vertical, 4)
            }
            .listRowBackground(canSave ? Color.brandDeepIndigo : Color.gray)
            .disabled(!canSave || isSaving)
        }
    }

    // MARK: - Validation

    private var effectiveDepartment: String {
        useNewDept ? newDeptName.trimmingCharacters(in: .whitespaces)
                   : department
    }

    private var canSave: Bool {
        let trimID   = equipmentId.trimmingCharacters(in: .whitespaces)
        let trimDesc = description.trimmingCharacters(in: .whitespaces)
        let trimDept = effectiveDepartment
        return !trimID.isEmpty && !trimDesc.isEmpty && !trimDept.isEmpty && idError == nil
    }

    private func validateID(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { idError = nil; return }
        let isDuplicate = vm.allEquipment.contains { $0.equipmentId == trimmed }
        idError = isDuplicate ? "Equipment ID already exists." : nil
    }

    // MARK: - Save

    private func save() async {
        let trimID   = equipmentId.trimmingCharacters(in: .whitespaces)
        let trimDesc = description.trimmingCharacters(in: .whitespaces)
        let trimDept = effectiveDepartment
        let trimPfx  = prefix.trimmingCharacters(in: .whitespaces).isEmpty
                       ? String(trimID.prefix(while: { $0 != "-" }))
                       : prefix.trimmingCharacters(in: .whitespaces)
        let trimNotes = notes.trimmingCharacters(in: .whitespaces)

        guard !trimID.isEmpty, !trimDesc.isEmpty, !trimDept.isEmpty else { return }

        isSaving   = true
        saveError  = nil
        defer { isSaving = false }

        let row = SupabaseService.NewEquipmentRow(
            equipmentId:     trimID,
            description:     trimDesc,
            department:      trimDept,
            prefix:          trimPfx,
            needsEquipPhoto: needsEquipPhoto,
            needsIsoPhoto:   needsIsoPhoto,
            notes:           trimNotes.isEmpty ? nil : trimNotes
        )

        do {
            _ = try await SupabaseService.shared.insertEquipment([row])
            await vm.loadEquipment()
            dismiss()
        } catch {
            saveError = (error as? SupabaseError)?.errorDescription ?? error.localizedDescription
        }
    }
}

#Preview {
    AddEquipmentView().environment(PlacardViewModel())
}

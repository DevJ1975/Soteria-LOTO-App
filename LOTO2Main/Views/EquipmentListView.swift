//
//  EquipmentListView.swift
//  LOTO2Main
//
//  iPad-optimised NavigationSplitView — department list on the left,
//  equipment rows in the middle, placard form on the right.
//  Uses pre-cached + debounced data from PlacardViewModel.
//

import SwiftUI

struct EquipmentListView: View {

    @Environment(PlacardViewModel.self) private var vm
    @State private var selectedDepartment: String?
    @State private var selectedEquipment:  Equipment?
    @State private var showBatchPrint      = false
    @State private var columnVisibility    = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // MARK: Sidebar — Departments
            sidebarColumn
        } content: {
            // MARK: Content — Equipment Rows
            equipmentColumn
        } detail: {
            // MARK: Detail — Placard Form
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showBatchPrint) {
            BatchPrintView().environment(vm)
        }
        .tint(Color.brandDeepIndigo)
    }

    // MARK: - Sidebar: Department List

    private var sidebarColumn: some View {
        List(selection: $selectedDepartment) {
            // Stats header
            Section {
                statsRow
            }

            // "All" option
            Label("All Equipment", systemImage: "list.bullet")
                .tag(String?.none as String?)
                .badge(vm.allEquipment.count)

            // Per-department
            Section("Departments") {
                ForEach(vm.departments, id: \.self) { dept in
                    let count = vm.allEquipment.filter { $0.department == dept }.count
                    Label(dept, systemImage: "building.2")
                        .tag(Optional(dept))
                        .badge(count)
                }
            }
        }
        .navigationTitle("LOTO Placard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showBatchPrint = true } label: {
                    Image(systemName: "printer")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await vm.loadEquipment() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .overlay {
            if vm.loadState == .loading { loadingOverlay }
        }
    }

    // MARK: - Content: Equipment Rows

    private var equipmentColumn: some View {
        Group {
            switch vm.loadState {
            case .error(let msg):
                errorView(msg)
            default:
                List(selection: $selectedEquipment) {
                    ForEach(displayedGroups, id: \.department) { group in
                        equipmentSection(group)
                    }
                }
                .listStyle(.insetGrouped)
                .animation(.default, value: vm.filteredGroups.map { $0.department })
            }
        }
        .navigationTitle(selectedDepartment ?? "All Equipment")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: Binding(get: { vm.searchText }, set: { vm.searchText = $0 }),
            prompt: "Search equipment"
        )
        .onChange(of: selectedEquipment) { _, equipment in
            if let equipment { vm.select(equipment) }
        }
    }

    // MARK: - Detail: Placard Form

    private var detailColumn: some View {
        Group {
            if let equipment = selectedEquipment {
                PlacardFormView(equipment: equipment)
                    .environment(vm)
                    .id(equipment.id) // force reinit when selection changes
            } else {
                emptyDetail
            }
        }
    }

    // MARK: - Computed Display Data

    private var displayedGroups: [(department: String, items: [Equipment])] {
        let groups = vm.searchText.isEmpty ? vm.groupedEquipment : vm.filteredGroups
        if let dept = selectedDepartment {
            return groups.filter { $0.department == dept }
        }
        return groups
    }

    // MARK: - Row Views

    @ViewBuilder
    private func equipmentSection(_ group: (department: String, items: [Equipment])) -> some View {
        Section(header: deptHeader(group.department, count: group.items.count)) {
            ForEach(group.items) { item in
                equipmentRow(item).tag(item)
            }
        }
    }

    private func equipmentRow(_ equipment: Equipment) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor(equipment.photoStatus))
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 2) {
                Text(equipment.equipmentId)
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundStyle(Color.brandDeepIndigo)
                Text(equipment.shortName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(equipment.photoStatus.capitalized)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(statusColor(equipment.photoStatus).opacity(0.15))
                    .foregroundStyle(statusColor(equipment.photoStatus))
                    .clipShape(Capsule())

                if equipment.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.statusSuccess)
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func deptHeader(_ name: String, count: Int) -> some View {
        HStack {
            Text(name.uppercased()).font(.caption.bold()).foregroundStyle(Color.sectionLabel)
            Spacer()
            Text("\(count)").font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(value: vm.allEquipment.count, label: "Total", color: Color.brandDeepIndigo)
            Divider().frame(height: 28)
            statCell(value: vm.countComplete, label: "Done",    color: Color.statusSuccess)
            Divider().frame(height: 28)
            statCell(value: vm.countPartial,  label: "Partial", color: Color.statusWarning)
            Divider().frame(height: 28)
            statCell(value: vm.countMissing,  label: "Missing", color: Color.statusError)
        }
        .padding(.vertical, 4)
    }

    private func statCell(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text("\(value)").font(.headline.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty Detail

    private var emptyDetail: some View {
        VStack(spacing: 16) {
            Image("SnakKingLogo")
                .resizable().scaledToFit()
                .frame(width: 200)
                .opacity(0.3)
            Text("Select an equipment item\nto begin the LOTO placard")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Loading…").font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle).foregroundStyle(Color.statusError)
            Text("Could not load equipment").font(.headline)
            Text(message).font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)
            Button("Retry") { Task { await vm.loadEquipment() } }
                .buttonStyle(.borderedProminent).tint(Color.brandDeepIndigo)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "complete": return Color.statusSuccess
        case "partial":  return Color.statusWarning
        default:         return Color.statusError
        }
    }
}

#Preview {
    EquipmentListView().environment(PlacardViewModel())
}

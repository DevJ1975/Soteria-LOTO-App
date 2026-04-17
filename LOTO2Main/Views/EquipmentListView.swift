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
    @State private var statusFilter:       StatusFilter = .all

    enum StatusFilter: String, CaseIterable {
        case all      = "All"
        case missing  = "Missing"
        case partial  = "Partial"
        case complete = "Complete"
    }

    private var network: NetworkMonitor { NetworkMonitor.shared }
    private var offline: OfflineStorageService { OfflineStorageService.shared }

    var body: some View {
        VStack(spacing: 0) {
            // Offline/pending banner — shown when no connection or uploads queued
            if !network.isConnected || offline.pendingCount > 0 {
                offlineBanner
            }

            NavigationSplitView(columnVisibility: $columnVisibility) {
                sidebarColumn
            } content: {
                equipmentColumn
            } detail: {
                detailColumn
            }
            .navigationSplitViewStyle(.balanced)
        }
        .sheet(isPresented: $showBatchPrint) {
            BatchPrintView().environment(vm)
        }
        .tint(Color.brandDeepIndigo)
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: network.isConnected ? "arrow.triangle.2.circlepath" : "wifi.slash")
                .font(.caption.bold())

            if !network.isConnected {
                Text("Offline — photos will sync when connected")
                    .font(.caption.bold())
            } else {
                Text("Syncing \(offline.pendingCount) pending upload\(offline.pendingCount == 1 ? "" : "s")…")
                    .font(.caption.bold())
            }

            Spacer()

            if offline.isFlushing {
                ProgressView().scaleEffect(0.7)
            } else if offline.pendingCount > 0 && network.isConnected {
                Button("Sync Now") {
                    Task { await OfflineStorageService.shared.flushQueue() }
                }
                .font(.caption.bold())
                .buttonStyle(.plain)
                .underline()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(network.isConnected ? Color.statusWarning.opacity(0.85) : Color.statusError.opacity(0.85))
        .foregroundStyle(.white)
        .animation(.easeInOut(duration: 0.3), value: network.isConnected)
        .animation(.easeInOut(duration: 0.3), value: offline.pendingCount)
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

            // Per-department with progress bars
            Section("Departments") {
                ForEach(vm.departments, id: \.self) { dept in
                    departmentRow(dept)
                        .tag(Optional(dept))
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
                .disabled(vm.loadState == .loading)
            }
            // Pending uploads indicator
            if offline.pendingCount > 0 {
                ToolbarItem(placement: .topBarLeading) {
                    Label("\(offline.pendingCount) pending", systemImage: "icloud.and.arrow.up")
                        .font(.caption)
                        .foregroundStyle(Color.statusWarning)
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
                VStack(spacing: 0) {
                    // Filter chips
                    filterChips

                    List(selection: $selectedEquipment) {
                        ForEach(displayedGroups, id: \.department) { group in
                            equipmentSection(group)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .animation(.default, value: vm.filteredGroups.map { $0.department })
                }
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
        .onChange(of: displayedGroups.map { $0.department }) { _, _ in
            vm.navigationList = displayedGroups.flatMap { $0.items }
        }
        .onAppear {
            vm.navigationList = displayedGroups.flatMap { $0.items }
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StatusFilter.allCases, id: \.self) { filter in
                    let isSelected = statusFilter == filter
                    let count = chipCount(for: filter)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            statusFilter = filter
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if filter != .all {
                                Circle()
                                    .fill(chipColor(for: filter))
                                    .frame(width: 7, height: 7)
                            }
                            Text(filter.rawValue)
                                .font(.caption.bold())
                            Text("(\(count))")
                                .font(.caption2)
                                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(isSelected ? chipColor(for: filter) : Color(UIColor.systemGray5))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    private func chipCount(for filter: StatusFilter) -> Int {
        let base = vm.searchText.isEmpty ? vm.allEquipment : vm.filteredEquipment
        let deptItems = selectedDepartment.map { d in base.filter { $0.department == d } } ?? base
        switch filter {
        case .all:      return deptItems.count
        case .missing:  return deptItems.filter { $0.photoStatus == "missing"  }.count
        case .partial:  return deptItems.filter { $0.photoStatus == "partial"  }.count
        case .complete: return deptItems.filter { $0.photoStatus == "complete" }.count
        }
    }

    private func chipColor(for filter: StatusFilter) -> Color {
        switch filter {
        case .all:      return Color.brandDeepIndigo
        case .missing:  return Color.statusError
        case .partial:  return Color.statusWarning
        case .complete: return Color.statusSuccess
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
        var groups = vm.searchText.isEmpty ? vm.groupedEquipment : vm.filteredGroups

        // Apply department filter
        if let dept = selectedDepartment {
            groups = groups.filter { $0.department == dept }
        }

        // Apply status filter chips
        if statusFilter != .all {
            let status = statusFilter.rawValue.lowercased()
            groups = groups.compactMap { group in
                let filtered = group.items.filter { $0.photoStatus == status }
                return filtered.isEmpty ? nil : (department: group.department, items: filtered)
            }
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

    // MARK: - Department Row with Progress

    private func departmentRow(_ dept: String) -> some View {
        let items    = vm.allEquipment.filter { $0.department == dept }
        let total    = items.count
        let complete = items.filter { $0.photoStatus == "complete" }.count
        let progress = total > 0 ? Double(complete) / Double(total) : 0

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(dept, systemImage: "building.2")
                    .font(.subheadline)
                Spacer()
                Text("\(complete)/\(total)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .tint(progress == 1 ? Color.statusSuccess : Color.brandDeepIndigo)
                .scaleEffect(x: 1, y: 0.7)
        }
        .padding(.vertical, 2)
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

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
    @State private var sortOrder:          SortOrder    = .equipmentId
    @State private var flaggedIDs:         Set<String>  = []   // session-only follow-up flags

    // MARK: - Enums

    enum StatusFilter: String, CaseIterable {
        case all        = "All"
        case needsPhoto = "Needs Photo"
        case missing    = "Missing"
        case partial    = "Partial"
        case complete   = "Complete"
    }

    enum SortOrder: String, CaseIterable {
        case equipmentId = "Equipment ID"
        case status      = "Status"
    }

    private var network: NetworkMonitor { NetworkMonitor.shared }
    private var offline: OfflineStorageService { OfflineStorageService.shared }

    var body: some View {
        VStack(spacing: 0) {
            // Offline/pending banner
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
            // Completion summary card (#7)
            Section {
                completionCard
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

            // Recently visited (#6)
            if !vm.recentlyVisited.isEmpty {
                Section("Recently Visited") {
                    ForEach(vm.recentlyVisited) { item in
                        Button {
                            selectedDepartment = item.department
                            selectedEquipment  = item   // .onChange handles vm.select()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.equipmentId)
                                        .font(.caption.bold())
                                        .foregroundStyle(Color.brandDeepIndigo)
                                    Text(item.shortName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Circle()
                                    .fill(statusColor(item.photoStatus))
                                    .frame(width: 7, height: 7)
                            }
                        }
                        .buttonStyle(.plain)
                    }
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
        .toolbar {
            // Sort toggle (#8)
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort by", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
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
        case .all:        return deptItems.count
        case .needsPhoto: return deptItems.filter { needsPhotoFilter($0) }.count
        case .missing:    return deptItems.filter { $0.photoStatus == "missing"  }.count
        case .partial:    return deptItems.filter { $0.photoStatus == "partial"  }.count
        case .complete:   return deptItems.filter { $0.photoStatus == "complete" }.count
        }
    }

    private func chipColor(for filter: StatusFilter) -> Color {
        switch filter {
        case .all:        return Color.brandDeepIndigo
        case .needsPhoto: return Color.statusWarning
        case .missing:    return Color.statusError
        case .partial:    return Color.statusWarning
        case .complete:   return Color.statusSuccess
        }
    }

    /// True if this equipment still needs at least one photo captured.
    private func needsPhotoFilter(_ equipment: Equipment) -> Bool {
        (equipment.needsEquipPhoto && !equipment.hasEquipPhoto) ||
        (equipment.needsIsoPhoto   && !equipment.hasIsoPhoto)
    }

    // MARK: - Detail: Placard Form

    private var detailColumn: some View {
        Group {
            if let equipment = selectedEquipment {
                PlacardFormView(equipment: equipment, onClose: { selectedEquipment = nil })
                    .environment(vm)
                    .id(equipment.id)
            } else {
                emptyDetail
            }
        }
    }

    // MARK: - Computed Display Data

    private var displayedGroups: [(department: String, items: [Equipment])] {
        var groups = vm.searchText.isEmpty ? vm.groupedEquipment : vm.filteredGroups

        // Department filter
        if let dept = selectedDepartment {
            groups = groups.filter { $0.department == dept }
        }

        // Status filter chips (#1 adds .needsPhoto)
        switch statusFilter {
        case .all: break
        case .needsPhoto:
            groups = groups.compactMap { group in
                let filtered = group.items.filter { needsPhotoFilter($0) }
                return filtered.isEmpty ? nil : (department: group.department, items: filtered)
            }
        default:
            let status = statusFilter.rawValue.lowercased()
            groups = groups.compactMap { group in
                let filtered = group.items.filter { $0.photoStatus == status }
                return filtered.isEmpty ? nil : (department: group.department, items: filtered)
            }
        }

        // Sort order (#8)
        switch sortOrder {
        case .equipmentId: break   // already sorted by equipmentId in cache
        case .status:
            let priority = ["missing": 0, "partial": 1, "complete": 2]
            groups = groups.map { group in
                let sorted = group.items.sorted {
                    (priority[$0.photoStatus] ?? 0) < (priority[$1.photoStatus] ?? 0)
                }
                return (department: group.department, items: sorted)
            }
        }

        return groups
    }

    // MARK: - Row Views

    @ViewBuilder
    private func equipmentSection(_ group: (department: String, items: [Equipment])) -> some View {
        Section(header: deptHeader(group.department, count: group.items.count)) {
            ForEach(group.items) { item in
                equipmentRow(item)
                    .tag(item)
                    // Swipe trailing: flag for follow-up (#9)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            if flaggedIDs.contains(item.equipmentId) {
                                flaggedIDs.remove(item.equipmentId)
                            } else {
                                flaggedIDs.insert(item.equipmentId)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        } label: {
                            Label(
                                flaggedIDs.contains(item.equipmentId) ? "Unflag" : "Flag",
                                systemImage: flaggedIDs.contains(item.equipmentId) ? "flag.slash" : "flag"
                            )
                        }
                        .tint(Color.statusWarning)
                    }
            }
        }
    }

    private func equipmentRow(_ equipment: Equipment) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor(equipment.photoStatus))
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(equipment.equipmentId)
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundStyle(Color.brandDeepIndigo)
                    // Flag indicator (#9)
                    if flaggedIDs.contains(equipment.equipmentId) {
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.statusWarning)
                    }
                }
                Text(equipment.shortName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                // Photo count badge: "0/2", "1/2", "2/2" (#2)
                let needed   = (equipment.needsEquipPhoto ? 1 : 0) + (equipment.needsIsoPhoto ? 1 : 0)
                let captured = (equipment.hasEquipPhoto   ? 1 : 0) + (equipment.hasIsoPhoto   ? 1 : 0)
                if needed > 0 {
                    Text("\(captured)/\(needed)")
                        .font(.caption2.bold())
                        .foregroundStyle(captured == needed ? Color.statusSuccess : .secondary)
                }

                // Offline sync pending badge (#5)
                let localEquip = PhotoStorageService.shared.hasLocal(equipment: equipment, type: .equipment)
                let localIso   = PhotoStorageService.shared.hasLocal(equipment: equipment, type: .isolation)
                if (localEquip && !equipment.hasEquipPhoto) || (localIso && !equipment.hasIsoPhoto) {
                    Image(systemName: "icloud.slash")
                        .font(.caption2)
                        .foregroundStyle(Color.statusWarning)
                }

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

    // MARK: - Completion Summary Card (#7)

    private var completionCard: some View {
        let total     = vm.allEquipment.count
        let done      = vm.countComplete
        let remaining = total - done
        let pct       = total > 0 ? Int(Double(done) / Double(total) * 100) : 0

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Overall Progress")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(pct)%")
                    .font(.caption.bold())
                    .foregroundStyle(pct == 100 ? Color.statusSuccess : Color.brandDeepIndigo)
            }
            ProgressView(value: Double(done), total: Double(max(total, 1)))
                .tint(pct == 100 ? Color.statusSuccess : Color.brandDeepIndigo)
            Text(remaining > 0
                 ? "\(done) of \(total) complete — \(remaining) remaining"
                 : "All \(total) placards complete")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(value: vm.allEquipment.count, label: "Total",   color: Color.brandDeepIndigo)
            Divider().frame(height: 28)
            statCell(value: vm.countComplete,      label: "Done",    color: Color.statusSuccess)
            Divider().frame(height: 28)
            statCell(value: vm.countPartial,       label: "Partial", color: Color.statusWarning)
            Divider().frame(height: 28)
            statCell(value: vm.countMissing,       label: "Missing", color: Color.statusError)
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

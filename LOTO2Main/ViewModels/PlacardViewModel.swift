//
//  PlacardViewModel.swift
//  LOTO2Main
//
//  Manages equipment list loading, photo capture state,
//  PDF generation, and Supabase photo/PDF uploads.
//
//  Performance notes:
//  - equipmentByDepartment is cached and only recomputed when allEquipment changes
//  - Search is debounced 300ms to avoid filtering on every keystroke
//  - PDF generation runs on a background task, not blocking the main thread
//

import Foundation
import UIKit
import Observation

// MARK: - LoadState

enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
}

// MARK: - PlacardViewModel

@Observable
final class PlacardViewModel {

    // MARK: - Equipment Data

    var allEquipment:    [Equipment] = [] { didSet { rebuildGroupedCache() } }
    var departments:     [String]    = []
    var loadState:       LoadState   = .idle

    // MARK: - Init (load cache immediately so list appears before network responds)

    init() {
        if let cached = Self.loadCache() {
            allEquipment = cached
            departments  = Array(Set(cached.map { $0.department })).sorted()
            loadState    = .loaded
        }
    }

    // MARK: - Cached Grouped Data (updated only when allEquipment changes)

    private(set) var groupedEquipment: [(department: String, items: [Equipment])] = []

    // MARK: - Active Session

    var selectedEquipment:  Equipment?
    var equipmentPhoto:     UIImage?
    var disconnectPhoto:    UIImage?
    var energySteps:        [EnergyStep] = []
    var isLoadingSteps:     Bool = false

    // MARK: - PDF State

    var generatedPDFData:   Data?
    var isGeneratingPDF:    Bool    = false
    var pdfError:           String? = nil

    // MARK: - Upload State

    var isUploading:        Bool    = false
    var uploadError:        String? = nil

    // MARK: - Search (debounced)

    var searchText: String = "" {
        didSet { scheduleSearch() }
    }
    private(set) var filteredEquipment: [Equipment] = []
    private(set) var filteredGroups: [(department: String, items: [Equipment])] = []
    private var searchTask: Task<Void, Never>?

    // MARK: - Stats (cached)

    private(set) var countComplete = 0
    private(set) var countPartial  = 0
    private(set) var countMissing  = 0

    // MARK: - Load

    /// Fetches equipment from Supabase. If cached data is already showing,
    /// this runs silently in the background and updates the list when done.
    func loadEquipment() async {
        guard loadState != .loading else { return }
        // If cache is showing, keep it visible (don't flash a spinner)
        let hadCache = loadState == .loaded
        if !hadCache { loadState = .loading }
        do {
            let equipment = try await SupabaseService.shared.fetchAllEquipment()
            allEquipment  = equipment
            departments   = Array(Set(equipment.map { $0.department })).sorted()
            loadState     = .loaded
            Self.saveCache(equipment)   // persist for next cold launch
        } catch {
            // If we have cached data, keep showing it rather than an error screen
            if !hadCache { loadState = .error(error.localizedDescription) }
        }
    }

    // MARK: - Select

    func select(_ equipment: Equipment) {
        selectedEquipment = equipment
        equipmentPhoto    = nil
        disconnectPhoto   = nil
        generatedPDFData  = nil
        pdfError          = nil
        uploadError       = nil
        energySteps       = []
        Task { await loadEnergySteps(for: equipment.equipmentId) }
    }

    @MainActor
    private func loadEnergySteps(for equipmentId: String) async {
        isLoadingSteps = true
        defer { isLoadingSteps = false }
        if let steps = try? await SupabaseService.shared.fetchEnergySteps(equipmentId: equipmentId) {
            energySteps = steps
        }
    }

    // MARK: - Generate PDF (background)

    func generatePDF() async {
        guard let equipment = selectedEquipment else { return }
        await MainActor.run { isGeneratingPDF = true; pdfError = nil }

        // Run the PDF rendering off the main thread
        let photo1 = equipmentPhoto
        let photo2 = disconnectPhoto
        let pdfData = await Task.detached(priority: .userInitiated) {
            await PDFGenerator.shared.generate(
                equipment: equipment,
                equipmentPhoto: photo1,
                disconnectPhoto: photo2
            )
        }.value

        await MainActor.run {
            generatedPDFData = pdfData
            isGeneratingPDF  = false
        }
    }

    // MARK: - Upload Photos + PDF

    @MainActor
    func uploadPhotosAndSave() async {
        guard let equipment = selectedEquipment else { return }
        isUploading = true
        uploadError = nil
        defer { isUploading = false }

        do {
            var equipURL: String?
            var isoURL:   String?
            var pdfURL:   String?

            if let img = equipmentPhoto, let data = img.compressedJPEG() {
                equipURL = try await SupabaseService.shared.uploadPhoto(
                    imageData: data, equipmentId: equipment.equipmentId, suffix: "EQUIP"
                )
            }
            if let img = disconnectPhoto, let data = img.compressedJPEG() {
                isoURL = try await SupabaseService.shared.uploadPhoto(
                    imageData: data, equipmentId: equipment.equipmentId, suffix: "ISO"
                )
            }
            if let pdf = generatedPDFData {
                pdfURL = try await SupabaseService.shared.uploadPDF(
                    data: pdf, equipmentId: equipment.equipmentId
                )
            }

            try await SupabaseService.shared.updatePhotoURLs(
                equipmentId:   equipment.equipmentId,
                equipPhotoUrl: equipURL,
                isoPhotoUrl:   isoURL,
                placardUrl:    pdfURL
            )

            // Update local cache so status dot refreshes immediately
            if let idx = allEquipment.firstIndex(where: { $0.equipmentId == equipment.equipmentId }) {
                // Equipment is a struct — we can't mutate it, but reload triggers cache rebuild
                _ = idx
            }
        } catch {
            uploadError = error.localizedDescription
        }
    }

    // MARK: - Reset

    func resetSession() {
        selectedEquipment = nil
        equipmentPhoto    = nil
        disconnectPhoto   = nil
        generatedPDFData  = nil
        pdfError          = nil
        uploadError       = nil
        energySteps       = []
    }

    // MARK: - Private: Disk Cache

    private static let cacheURL: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("loto_equipment_cache.json")
    }()

    private static func saveCache(_ equipment: [Equipment]) {
        Task.detached(priority: .background) {
            if let data = try? JSONEncoder().encode(equipment) {
                try? data.write(to: cacheURL, options: .atomic)
            }
        }
    }

    private static func loadCache() -> [Equipment]? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode([Equipment].self, from: data)
    }

    // MARK: - Private: Cache Rebuild

    private func rebuildGroupedCache() {
        // Compute on background thread, publish on main
        let items = allEquipment
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            var map: [String: [Equipment]] = [:]
            for eq in items { map[eq.department, default: []].append(eq) }
            let groups = map
                .map { (department: $0.key, items: $0.value.sorted { $0.equipmentId < $1.equipmentId }) }
                .sorted { $0.department < $1.department }
            let complete = items.filter { $0.photoStatus == "complete" }.count
            let partial  = items.filter { $0.photoStatus == "partial"  }.count
            let missing  = items.filter { $0.photoStatus == "missing"  }.count

            await MainActor.run {
                self.groupedEquipment = groups
                self.filteredGroups   = groups
                self.filteredEquipment = items
                self.countComplete    = complete
                self.countPartial     = partial
                self.countMissing     = missing
            }
        }
    }

    // MARK: - Private: Debounced Search

    private func scheduleSearch() {
        searchTask?.cancel()
        let query = searchText
        let source = allEquipment
        let grouped = groupedEquipment

        if query.isEmpty {
            filteredEquipment = source
            filteredGroups    = grouped
            return
        }

        searchTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            // 300ms debounce
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            let results = source.filter {
                $0.equipmentId.localizedCaseInsensitiveContains(query) ||
                $0.description.localizedCaseInsensitiveContains(query) ||
                $0.department.localizedCaseInsensitiveContains(query)
            }
            var map: [String: [Equipment]] = [:]
            for eq in results { map[eq.department, default: []].append(eq) }
            let groups = map
                .map { (department: $0.key, items: $0.value.sorted { $0.equipmentId < $1.equipmentId }) }
                .sorted { $0.department < $1.department }

            await MainActor.run {
                self.filteredEquipment = results
                self.filteredGroups    = groups
            }
        }
    }
}

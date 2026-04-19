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

    var selectedEquipment:      Equipment?
    var equipmentPhoto:         UIImage?
    var disconnectPhoto:        UIImage?
    var existingEquipPhoto:     UIImage?   // previously uploaded, loaded from Supabase URL
    var existingIsoPhoto:       UIImage?   // previously uploaded, loaded from Supabase URL
    var isLoadingExistingPhotos: Bool = false
    var energySteps:            [EnergyStep] = []
    var isLoadingSteps:         Bool = false

    // MARK: - PDF State

    var generatedPDFData:   Data?
    var isGeneratingPDF:    Bool    = false
    var pdfError:           String? = nil

    // MARK: - Per-photo upload state (shown as indicators on each photo slot)

    var isUploadingEquipPhoto: Bool    = false
    var isUploadingIsoPhoto:   Bool    = false
    var equipPhotoUploaded:    Bool    = false
    var isoPhotoUploaded:      Bool    = false

    // MARK: - Upload State

    var isUploading:        Bool    = false
    var uploadStep:         String  = ""      // current step label shown in progress overlay
    var uploadError:        String? = nil
    var savedOffline:       Bool    = false   // true = queued for later sync

    // MARK: - Spanish Translation State

    var spanishSaveError: String? = nil

    /// One pending Spanish edit for a single energy step.
    struct SpanishStepEdit {
        let stepId: UUID
        let tagDescriptionEs: String?
        let isolationProcedureEs: String?
        let methodOfVerificationEs: String?
    }

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
        let hadCache = loadState == .loaded
        if !hadCache { loadState = .loading }
        do {
            let equipment = try await SupabaseService.shared.fetchAllEquipment()
            allEquipment  = equipment
            departments   = Array(Set(equipment.map { $0.department })).sorted()
            loadState     = .loaded
            Self.saveCache(equipment)
        } catch {
            if !hadCache { loadState = .error(error.localizedDescription) }
        }
    }

    // MARK: - Network-aware refresh + sync

    /// Call once on app launch. Re-fetches equipment and flushes the offline
    /// upload queue whenever the device reconnects to the internet.
    func startNetworkSync() {
        Task { [weak self] in
            var prev = NetworkMonitor.shared.isConnected
            while !Task.isCancelled {
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = NetworkMonitor.shared.isConnected
                    } onChange: {
                        continuation.resume()
                    }
                }
                let now = NetworkMonitor.shared.isConnected
                if now && !prev {
                    // Just reconnected — refresh data only. Uploads are manual.
                    await self?.loadEquipment()
                }
                prev = now
            }
        }
    }

    // MARK: - Recently Visited (last 10, session-only)

    private(set) var recentlyVisited: [Equipment] = []

    private func markVisited(_ equipment: Equipment) {
        recentlyVisited.removeAll { $0.equipmentId == equipment.equipmentId }
        recentlyVisited.insert(equipment, at: 0)
        if recentlyVisited.count > 10 { recentlyVisited = Array(recentlyVisited.prefix(10)) }
    }

    // MARK: - Navigation context (set by EquipmentListView so Next works)

    var navigationList: [Equipment] = []

    /// Returns the equipment item after the current selection in navigationList.
    var nextEquipment: Equipment? {
        guard let current = selectedEquipment,
              let idx = navigationList.firstIndex(of: current),
              idx + 1 < navigationList.count
        else { return nil }
        return navigationList[idx + 1]
    }

    // MARK: - Background WiFi Photo Sync (#4)

    /// Scans local photo storage for any photos that were saved offline but not yet uploaded.
    /// Uploads them silently in the background. Only runs when connected.
    @MainActor
    func scanAndUploadMissingPhotos() async {
        guard NetworkMonitor.shared.isConnected else { return }
        let candidates = allEquipment.filter { !$0.hasEquipPhoto || !$0.hasIsoPhoto }
        for item in candidates {
            guard NetworkMonitor.shared.isConnected else { break }
            if !item.hasEquipPhoto,
               let img = PhotoStorageService.shared.loadLocal(equipment: item, type: .equipment) {
                await uploadPhoto(image: img, equipment: item, type: .equipment)
            }
            if !item.hasIsoPhoto,
               let img = PhotoStorageService.shared.loadLocal(equipment: item, type: .isolation) {
                await uploadPhoto(image: img, equipment: item, type: .isolation)
            }
        }
    }

    // MARK: - Photo Capture (called immediately when camera/picker returns an image)

    /// Called the moment a photo is taken or chosen. Saves locally with EXIF tags,
    /// then uploads to Supabase in the background. UI updates instantly.
    func photoTaken(_ image: UIImage, type: LOTOPhotoType) {
        guard let equipment = selectedEquipment else { return }

        // 1. Update in-memory state immediately (UI sees photo right away)
        switch type {
        case .equipment: equipmentPhoto = image; equipPhotoUploaded = false
        case .isolation: disconnectPhoto = image; isoPhotoUploaded  = false
        }
        savedOffline = false
        uploadError  = nil

        // 2. Save locally with EXIF + proper filename (async, off main thread)
        PhotoStorageService.shared.saveLocally(image: image, equipment: equipment, type: type)

        // 3. Update local status immediately — missing / partial / complete
        if let idx = allEquipment.firstIndex(where: { $0.equipmentId == equipment.equipmentId }) {
            var updated = allEquipment[idx]
            switch type {
            case .equipment: updated.hasEquipPhoto = true
            case .isolation: updated.hasIsoPhoto   = true
            }
            updated.photoStatus = updated.hasEquipPhoto && updated.hasIsoPhoto ? "complete"
                                 : (updated.hasEquipPhoto || updated.hasIsoPhoto) ? "partial"
                                 : "missing"
            allEquipment[idx] = updated   // triggers rebuildGroupedCache() via didSet
        }
        // Upload is manual — tap the Upload button in the toolbar when ready.
    }

    @MainActor
    private func uploadPhoto(image: UIImage, equipment: Equipment, type: LOTOPhotoType) async {
        guard NetworkMonitor.shared.isConnected else {
            // Offline — local copy already saved by PhotoStorageService.
            // Queue for sync when connectivity returns.
            let data = image.compressedJPEG()
            OfflineStorageService.shared.queue(
                equipmentId: equipment.equipmentId,
                equipPhoto:  type == .equipment ? data : nil,
                isoPhoto:    type == .isolation  ? data : nil,
                pdf:         nil
            )
            return
        }

        switch type {
        case .equipment: isUploadingEquipPhoto = true
        case .isolation: isUploadingIsoPhoto   = true
        }
        defer {
            switch type {
            case .equipment: isUploadingEquipPhoto = false
            case .isolation: isUploadingIsoPhoto   = false
            }
        }

        guard let compressed = image.compressedJPEG() else { return }

        do {
            let uploadedURL = try await SupabaseService.shared.uploadPhoto(
                imageData: compressed,
                equipmentId: equipment.equipmentId,
                suffix: type.rawValue
            )

            // Determine new photo_status from what exists + what we just uploaded
            let currentItem = allEquipment.first { $0.equipmentId == equipment.equipmentId }
            let willHaveEquip = type == .equipment || (currentItem?.hasEquipPhoto ?? false)
            let willHaveIso   = type == .isolation  || (currentItem?.hasIsoPhoto  ?? false)
            let newStatus     = (willHaveEquip && willHaveIso) ? "complete" : "partial"

            // Patch Supabase row — URLs + status + boolean flags in one call
            try await SupabaseService.shared.updatePhotoURLs(
                equipmentId:   equipment.equipmentId,
                equipPhotoUrl: type == .equipment ? uploadedURL : nil,
                isoPhotoUrl:   type == .isolation  ? uploadedURL : nil,
                photoStatus:   newStatus,
                hasEquipPhoto: type == .equipment ? true : nil,
                hasIsoPhoto:   type == .isolation  ? true : nil
            )

            // Update local cache immediately — no full re-fetch needed
            if let idx = allEquipment.firstIndex(where: { $0.equipmentId == equipment.equipmentId }) {
                var updated = allEquipment[idx]
                switch type {
                case .equipment:
                    updated.equipPhotoUrl = uploadedURL
                    updated.hasEquipPhoto = true
                case .isolation:
                    updated.isoPhotoUrl = uploadedURL
                    updated.hasIsoPhoto = true
                }
                updated.photoStatus = newStatus
                allEquipment[idx] = updated   // triggers rebuildGroupedCache() via didSet
            }

            // Mark upload complete for UI badge
            switch type {
            case .equipment: equipPhotoUploaded = true
            case .isolation: isoPhotoUploaded   = true
            }

            // Haptic feedback on success
            UINotificationFeedbackGenerator().notificationOccurred(.success)

        } catch {
            uploadError = "Photo upload failed — queued for retry when reconnected."
            // Queue so the offline service retries on reconnect
            let data = image.compressedJPEG()
            OfflineStorageService.shared.queue(
                equipmentId: equipment.equipmentId,
                equipPhoto:  type == .equipment ? data : nil,
                isoPhoto:    type == .isolation  ? data : nil,
                pdf:         nil
            )
        }
    }

    // MARK: - Select

    func select(_ equipment: Equipment) {
        markVisited(equipment)
        selectedEquipment      = equipment
        generatedPDFData       = nil
        pdfError               = nil
        uploadError            = nil
        energySteps            = []
        equipPhotoUploaded     = false
        isoPhotoUploaded       = false
        isUploadingEquipPhoto  = false
        isUploadingIsoPhoto    = false

        // Load local photos first (instant, no network) —
        // then fall back to Supabase URL if not saved locally yet.
        equipmentPhoto  = PhotoStorageService.shared.loadLocal(equipment: equipment, type: .equipment)
        disconnectPhoto = PhotoStorageService.shared.loadLocal(equipment: equipment, type: .isolation)

        existingEquipPhoto = nil
        existingIsoPhoto   = nil

        Task { await loadEnergySteps(for: equipment.equipmentId) }

        // Only fetch remote previews for photos we don't have locally
        let needsEquip = equipmentPhoto  == nil
        let needsIso   = disconnectPhoto == nil
        if needsEquip || needsIso {
            Task { await loadExistingPhotos(for: equipment, equip: needsEquip, iso: needsIso) }
        }
    }

    @MainActor
    private func loadExistingPhotos(for equipment: Equipment, equip: Bool, iso: Bool) async {
        guard (equip && equipment.equipPhotoUrl != nil) ||
              (iso   && equipment.isoPhotoUrl   != nil) else { return }
        isLoadingExistingPhotos = true
        defer { isLoadingExistingPhotos = false }

        if equip, let url = equipment.equipPhotoUrl {
            if let img = await fetchRemoteImage(urlString: url) {
                // Cache locally so future visits are instant
                PhotoStorageService.shared.saveLocally(image: img, equipment: equipment, type: .equipment)
                existingEquipPhoto = img
                equipmentPhoto     = img
            }
        }
        if iso, let url = equipment.isoPhotoUrl {
            if let img = await fetchRemoteImage(urlString: url) {
                PhotoStorageService.shared.saveLocally(image: img, equipment: equipment, type: .isolation)
                existingIsoPhoto = img
                disconnectPhoto  = img
            }
        }
    }

    private func fetchRemoteImage(urlString: String?) async -> UIImage? {
        guard let str = urlString, let url = URL(string: str) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
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

        let photo1 = equipmentPhoto ?? existingEquipPhoto
        let photo2 = disconnectPhoto ?? existingIsoPhoto
        let steps  = energySteps
        let pdfData = await Task.detached(priority: .userInitiated) {
            await PDFGenerator.shared.generate(
                equipment: equipment,
                equipmentPhoto: photo1,
                disconnectPhoto: photo2,
                energySteps: steps
            )
        }.value

        await MainActor.run {
            generatedPDFData = pdfData
            isGeneratingPDF  = false
        }
    }

    // MARK: - Save Spanish Translations

    /// Saves Spanish translations to Supabase and updates the local cache.
    /// Returns true on success; sets spanishSaveError and returns false on failure.
    @MainActor
    func saveSpanishTranslations(equipment: Equipment,
                                  notesEs: String?,
                                  spanishReviewed: Bool,
                                  stepEdits: [SpanishStepEdit]) async -> Bool {
        spanishSaveError = nil
        do {
            // Update equipment-level Spanish fields
            try await SupabaseService.shared.updateEquipmentSpanish(
                equipmentId:     equipment.equipmentId,
                notesEs:         notesEs,
                spanishReviewed: spanishReviewed
            )

            // Update each energy step
            for edit in stepEdits {
                try await SupabaseService.shared.updateEnergyStepSpanish(
                    stepId:               edit.stepId,
                    tagDescriptionEs:     edit.tagDescriptionEs,
                    isolationProcedureEs: edit.isolationProcedureEs,
                    methodOfVerificationEs: edit.methodOfVerificationEs
                )
            }

            // Mirror to local allEquipment cache so the list refreshes immediately
            if let idx = allEquipment.firstIndex(where: { $0.equipmentId == equipment.equipmentId }) {
                var updated = allEquipment[idx]
                updated.notesEs         = notesEs
                updated.spanishReviewed = spanishReviewed
                allEquipment[idx] = updated
            }

            // Mirror to local energySteps so the form shows updated text without a re-fetch
            for edit in stepEdits {
                if let idx = energySteps.firstIndex(where: { $0.id == edit.stepId }) {
                    energySteps[idx].tagDescriptionEs         = edit.tagDescriptionEs
                    energySteps[idx].isolationProcedureEs     = edit.isolationProcedureEs
                    energySteps[idx].methodOfVerificationEs   = edit.methodOfVerificationEs
                }
            }

            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        } catch {
            spanishSaveError = error.localizedDescription
            return false
        }
    }

    // MARK: - Upload Photos + PDF

    @MainActor
    func uploadPhotosAndSave() async {
        guard let equipment = selectedEquipment else { return }

        // If offline, queue this placard and stop — user will upload later
        if !NetworkMonitor.shared.isConnected {
            queueForLater(equipment: equipment)
            uploadError  = nil
            savedOffline = true
            return
        }

        isUploading  = true
        uploadStep   = "Preparing…"
        uploadError  = nil
        savedOffline = false
        defer { isUploading = false; uploadStep = "" }

        do {
            var equipURL: String?
            var isoURL:   String?
            var pdfURL:   String?

            // Use the in-session photo if available, otherwise fall back to locally cached
            let equipImg = equipmentPhoto ?? existingEquipPhoto
            let isoImg   = disconnectPhoto ?? existingIsoPhoto

            if let img = equipImg, let data = img.compressedJPEG() {
                uploadStep = "Uploading equipment photo…"
                equipURL = try await SupabaseService.shared.uploadPhoto(
                    imageData: data, equipmentId: equipment.equipmentId, suffix: "EQUIP"
                )
            }
            if let img = isoImg, let data = img.compressedJPEG() {
                uploadStep = "Uploading isolation photo…"
                isoURL = try await SupabaseService.shared.uploadPhoto(
                    imageData: data, equipmentId: equipment.equipmentId, suffix: "ISO"
                )
            }
            if let pdf = generatedPDFData {
                uploadStep = "Uploading PDF placard…"
                pdfURL = try await SupabaseService.shared.uploadPDF(
                    data: pdf, equipmentId: equipment.equipmentId
                )
            }

            uploadStep = "Saving to database…"
            let willHaveEquip = equipURL != nil || equipment.hasEquipPhoto
            let willHaveIso   = isoURL   != nil || equipment.hasIsoPhoto
            let newStatus     = willHaveEquip && willHaveIso ? "complete"
                              : (willHaveEquip || willHaveIso) ? "partial" : "missing"

            try await SupabaseService.shared.updatePhotoURLs(
                equipmentId:   equipment.equipmentId,
                equipPhotoUrl: equipURL,
                isoPhotoUrl:   isoURL,
                placardUrl:    pdfURL,
                photoStatus:   newStatus,
                hasEquipPhoto: equipURL != nil ? true : nil,
                hasIsoPhoto:   isoURL   != nil ? true : nil
            )

            equipPhotoUploaded = equipURL != nil
            isoPhotoUploaded   = isoURL   != nil
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // Flush any placards queued while offline
            if OfflineStorageService.shared.pendingCount > 0 {
                uploadStep = "Syncing \(OfflineStorageService.shared.pendingCount) queued placard(s)…"
                await OfflineStorageService.shared.flushQueue()
            }

        } catch {
            // Upload failed mid-flight — queue so nothing is lost
            queueForLater(equipment: equipment)
            uploadError = "Upload failed — queued for next manual sync.\n\n\(error.localizedDescription)"
        }
    }

    private func queueForLater(equipment: Equipment) {
        let equipData = equipmentPhoto?.compressedJPEG()
        let isoData   = disconnectPhoto?.compressedJPEG()
        OfflineStorageService.shared.queue(
            equipmentId: equipment.equipmentId,
            equipPhoto:  equipData,
            isoPhoto:    isoData,
            pdf:         generatedPDFData
        )
    }

    // MARK: - Reset

    func resetSession() {
        selectedEquipment    = nil
        equipmentPhoto       = nil
        disconnectPhoto      = nil
        existingEquipPhoto   = nil
        existingIsoPhoto     = nil
        generatedPDFData     = nil
        pdfError             = nil
        uploadError          = nil
        energySteps          = []
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

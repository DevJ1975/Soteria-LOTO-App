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

    // MARK: - Department Sign-offs (persisted locally across sessions)

    struct DepartmentSignOff: Codable {
        let supervisorName: String
        let date: Date
        let signatureData: Data?   // JPEG-compressed drawn signature; nil = text-only sign-off
    }

    private static let signOffKey = "loto.department_signoffs"
    private(set) var departmentSignOffs: [String: DepartmentSignOff] = [:]

    func signOff(department: String, supervisorName: String, date: Date,
                 signatureImage: UIImage? = nil) {
        let sigData = signatureImage?.jpegData(compressionQuality: 0.8)
        departmentSignOffs[department] = DepartmentSignOff(
            supervisorName: supervisorName, date: date, signatureData: sigData
        )
        if let data = try? JSONEncoder().encode(departmentSignOffs) {
            UserDefaults.standard.set(data, forKey: Self.signOffKey)
        }
    }

    func clearSignOff(department: String) {
        departmentSignOffs.removeValue(forKey: department)
        if let data = try? JSONEncoder().encode(departmentSignOffs) {
            UserDefaults.standard.set(data, forKey: Self.signOffKey)
        }
    }

    private func loadSignOffs() {
        guard let data    = UserDefaults.standard.data(forKey: Self.signOffKey),
              let decoded = try? JSONDecoder().decode([String: DepartmentSignOff].self, from: data)
        else { return }
        departmentSignOffs = decoded
    }

    // MARK: - Decommissioned Equipment (persisted locally across sessions)

    private static let deprecatedKey = "loto.decommissioned_ids"
    private(set) var decommissionedIDs: Set<String> = []

    /// Toggles the decommissioned state for an equipment item and persists to UserDefaults.
    func toggleDecommissioned(_ equipment: Equipment) {
        if decommissionedIDs.contains(equipment.equipmentId) {
            decommissionedIDs.remove(equipment.equipmentId)
        } else {
            decommissionedIDs.insert(equipment.equipmentId)
        }
        UserDefaults.standard.set(Array(decommissionedIDs), forKey: Self.deprecatedKey)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // allEquipment hasn't changed, so didSet won't fire — trigger explicitly so
        // countActive, countComplete, and per-dept stats all reflect the new state.
        rebuildGroupedCache()
    }

    func isDecommissioned(_ equipment: Equipment) -> Bool {
        decommissionedIDs.contains(equipment.equipmentId)
    }

    /// Serialises the full equipment list to a CSV file and returns its URL for sharing.
    /// Includes all items (active + decommissioned) so the export is a complete inventory.
    func exportEquipmentCSV() -> URL {
        var lines: [String] = [
            "equipment_id,description,department,prefix,photo_status," +
            "has_equip_photo,has_iso_photo,needs_equip_photo,needs_iso_photo," +
            "verified,verified_by,verified_date,decommissioned,notes"
        ]
        for eq in allEquipment.sorted(by: { $0.equipmentId < $1.equipmentId }) {
            let row: [String] = [
                csvEscape(eq.equipmentId),
                csvEscape(eq.description),
                csvEscape(eq.department),
                csvEscape(eq.prefix),
                eq.photoStatus,
                eq.hasEquipPhoto  ? "true" : "false",
                eq.hasIsoPhoto    ? "true" : "false",
                eq.needsEquipPhoto ? "true" : "false",
                eq.needsIsoPhoto   ? "true" : "false",
                eq.verified        ? "true" : "false",
                csvEscape(eq.verifiedBy   ?? ""),
                csvEscape(eq.verifiedDate ?? ""),
                decommissionedIDs.contains(eq.equipmentId) ? "true" : "false",
                csvEscape(eq.notes ?? "")
            ]
            lines.append(row.joined(separator: ","))
        }
        let csv = lines.joined(separator: "\n")
        let f   = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let name = "LOTO_Equipment_Export_\(f.string(from: Date())).csv"
        let url  = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    /// Renames every equipment row in `oldName` to `newName` — both in Supabase
    /// and in the local cache — then rebuilds stats so the sidebar updates instantly.
    func renameDepartment(from oldName: String, to newName: String) async throws {
        try await SupabaseService.shared.renameDepartment(from: oldName, to: newName)
        // Update local cache so the sidebar reflects the change without a full reload.
        allEquipment = allEquipment.map { eq in
            guard eq.department == oldName else { return eq }
            let updated = eq
            // Equipment is a struct; re-encode/decode to get a copy with the new dept.
            // Since Equipment has no memberwise init exposed, we recreate via JSON round-trip.
            if let data    = try? JSONEncoder().encode(updated),
               var dict    = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                dict["department"] = newName
                if let patched = try? JSONSerialization.data(withJSONObject: dict),
                   let result  = try? JSONDecoder().decode(Equipment.self, from: patched) {
                    return result
                }
            }
            return updated
        }
        rebuildGroupedCache()
    }

    // MARK: - Init (load cache immediately so list appears before network responds)

    init() {
        decommissionedIDs = Set(
            UserDefaults.standard.stringArray(forKey: Self.deprecatedKey) ?? []
        )
        loadSignOffs()
        if let cached = Self.loadCache() {
            let reconciled = reconcileLocalPhotos(cached)
            allEquipment = reconciled
            departments  = Array(Set(reconciled.map { $0.department })).sorted()
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
    var lowStorageWarning:  Bool    = false   // true = < 100 MB free when photo was taken

    // MARK: - Spanish Translation State

    var spanishSaveError: String? = nil
    var stepEditError:    String? = nil

    /// One pending English edit for a single energy step.
    struct EnergyStepEdit {
        let stepId: UUID
        let tagDescription: String?
        let isolationProcedure: String?
        let methodOfVerification: String?
    }

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

    // Tracks in-flight background tasks so they can be cancelled when
    // the user switches to a different equipment item before they complete.
    private var energyStepTask: Task<Void, Never>?
    private var photoLoadTask:  Task<Void, Never>?

    // MARK: - Stats (cached, active equipment only — excludes decommissioned)

    private(set) var countActive   = 0   // non-decommissioned total
    private(set) var countComplete = 0
    private(set) var countPartial  = 0
    private(set) var countMissing  = 0

    // Per-department active stats — O(1) lookup for sidebar rows instead of O(n) filter per render
    private(set) var deptActiveCounts:   [String: Int] = [:]
    private(set) var deptCompleteCounts: [String: Int] = [:]

    // Cancels any in-flight rebuild when a new one starts (prevents stale-stats race)
    private var rebuildTask: Task<Void, Never>?

    // MARK: - Load

    /// Fetches equipment from Supabase. If cached data is already showing,
    /// this runs silently in the background and updates the list when done.
    func loadEquipment() async {
        guard loadState != .loading else { return }
        let hadCache = loadState == .loaded
        if !hadCache { loadState = .loading }
        do {
            let equipment  = try await SupabaseService.shared.fetchAllEquipment()
            let reconciled = reconcileLocalPhotos(equipment)
            allEquipment   = reconciled
            departments    = Array(Set(reconciled.map { $0.department })).sorted()
            loadState      = .loaded
            Self.saveCache(reconciled)
            // Silently push any photos saved locally but not yet in Supabase.
            // Runs after every successful load (launch + reconnect).
            Task { await scanAndUploadMissingPhotos() }
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

    // MARK: - Background WiFi Photo Sync

    private var isScanningPhotos = false

    /// Scans local photo storage for any photos saved on-device but not yet uploaded to Supabase.
    /// Uses the Supabase URL (nil = never uploaded) rather than the boolean flag, because
    /// reconcileLocalPhotos() may have already set hasEquipPhoto/hasIsoPhoto = true in memory
    /// while the remote URL is still absent. Runs silently; only active when connected.
    @MainActor
    func scanAndUploadMissingPhotos() async {
        guard NetworkMonitor.shared.isConnected, !isScanningPhotos else { return }
        isScanningPhotos = true
        defer { isScanningPhotos = false }

        for item in allEquipment where !decommissionedIDs.contains(item.equipmentId) {
            guard NetworkMonitor.shared.isConnected else { break }
            if item.equipPhotoUrl == nil,
               let img = PhotoStorageService.shared.loadLocal(equipment: item, type: .equipment) {
                await uploadPhoto(image: img, equipment: item, type: .equipment)
            }
            if item.isoPhotoUrl == nil,
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

        // Warn if storage is critically low (< 100 MB). A single compressed JPEG
        // is ~1-3 MB, so this gives enough headroom to surface the warning before
        // the disk fills up and silent write failures start occurring.
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        if let available = try? homeURL
                .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                .volumeAvailableCapacityForImportantUsage,
           available < 100_000_000 {
            lowStorageWarning = true
        }

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
            updated.photoStatus = computePhotoStatus(
                for: updated,
                willHaveEquip: updated.hasEquipPhoto,
                willHaveIso:   updated.hasIsoPhoto
            )
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

        // Only show the per-slot spinner when the user is viewing this equipment.
        // Background scans may upload items the user has already navigated away from.
        if selectedEquipment?.equipmentId == equipment.equipmentId {
            switch type {
            case .equipment: isUploadingEquipPhoto = true
            case .isolation: isUploadingIsoPhoto   = true
            }
        }
        defer {
            if selectedEquipment?.equipmentId == equipment.equipmentId {
                switch type {
                case .equipment: isUploadingEquipPhoto = false
                case .isolation: isUploadingIsoPhoto   = false
                }
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
            let newStatus     = computePhotoStatus(for: equipment,
                                                   willHaveEquip: willHaveEquip,
                                                   willHaveIso:   willHaveIso)

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

            // Mark upload complete for UI badge only if the user is still viewing
            // this equipment — background scans upload items the user may have left.
            if selectedEquipment?.equipmentId == equipment.equipmentId {
                switch type {
                case .equipment: equipPhotoUploaded = true
                case .isolation: isoPhotoUploaded   = true
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }

        } catch {
            // Only surface an error banner when the user is actively viewing this equipment.
            if selectedEquipment?.equipmentId == equipment.equipmentId {
                uploadError = "Photo upload failed. Saved locally — will retry when reconnected."
            }
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
        savedOffline           = false
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

        // Cancel any in-flight step fetch for the previously selected equipment.
        energyStepTask?.cancel()
        energyStepTask = Task { await loadEnergySteps(for: equipment.equipmentId) }

        // Cancel any in-flight remote photo download for the previous equipment.
        photoLoadTask?.cancel()

        // Only fetch remote previews for photos we don't have locally
        let needsEquip = equipmentPhoto  == nil
        let needsIso   = disconnectPhoto == nil
        if needsEquip || needsIso {
            photoLoadTask = Task {
                await loadExistingPhotos(for: equipment, equip: needsEquip, iso: needsIso)
            }
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
                // Guard: user may have navigated to a different equipment while we were fetching.
                // Writing into the wrong slot would show equipment A's photo on equipment B's form.
                guard !Task.isCancelled, selectedEquipment?.id == equipment.id else { return }
                // Cache locally so future visits are instant
                PhotoStorageService.shared.saveLocally(image: img, equipment: equipment, type: .equipment)
                existingEquipPhoto = img
                equipmentPhoto     = img
            }
        }
        if iso, let url = equipment.isoPhotoUrl {
            if let img = await fetchRemoteImage(urlString: url) {
                guard !Task.isCancelled, selectedEquipment?.id == equipment.id else { return }
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
            // Guard against a cancelled fetch (user navigated away) writing
            // its results over the steps for the newly selected equipment.
            guard !Task.isCancelled else { return }
            energySteps = steps
        }
    }

    // MARK: - Generate PDF (background)

    func generatePDF() async {
        guard let equipment = selectedEquipment else { return }
        await MainActor.run { isGeneratingPDF = true; pdfError = nil }

        let photo1   = equipmentPhoto ?? existingEquipPhoto
        let photo2   = disconnectPhoto ?? existingIsoPhoto
        let steps    = energySteps
        let signOff  = departmentSignOffs[equipment.department]
        let supName  = signOff?.supervisorName
        let soDate   = signOff?.date
        let sigImg   = signOff?.signatureData.flatMap { UIImage(data: $0) }
        let pdfData = await Task.detached(priority: .userInitiated) {
            await PDFGenerator.shared.generate(
                equipment: equipment,
                equipmentPhoto: photo1,
                disconnectPhoto: photo2,
                energySteps: steps,
                supervisorName: supName,
                signOffDate: soDate,
                signatureImage: sigImg
            )
        }.value

        await MainActor.run {
            generatedPDFData = pdfData
            isGeneratingPDF  = false
        }
    }

    // MARK: - Save Energy Step Edits (English)

    /// Saves English edits to energy steps in Supabase and updates the local cache.
    @MainActor
    func saveEnergyStepEdits(_ edits: [EnergyStepEdit]) async -> Bool {
        stepEditError = nil
        do {
            for edit in edits {
                try await SupabaseService.shared.updateEnergyStep(
                    stepId:               edit.stepId,
                    tagDescription:       edit.tagDescription,
                    isolationProcedure:   edit.isolationProcedure,
                    methodOfVerification: edit.methodOfVerification
                )
            }
            for edit in edits {
                if let idx = energySteps.firstIndex(where: { $0.id == edit.stepId }) {
                    if let t = edit.tagDescription       { energySteps[idx].tagDescription       = t }
                    if let i = edit.isolationProcedure   { energySteps[idx].isolationProcedure   = i }
                    if let m = edit.methodOfVerification { energySteps[idx].methodOfVerification = m }
                }
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        } catch {
            stepEditError = "Could not save step changes. Check your connection and try again."
            return false
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
            spanishSaveError = "Could not save translations. Check your connection and try again."
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

            // Only upload photos taken THIS session — don't re-upload existing remote photos.
            // existingEquipPhoto/existingIsoPhoto are remote images already stored in Supabase;
            // re-uploading them wastes bandwidth and creates duplicate storage objects.
            if let img = equipmentPhoto, let data = img.compressedJPEG() {
                uploadStep = "Uploading equipment photo…"
                equipURL = try await SupabaseService.shared.uploadPhoto(
                    imageData: data, equipmentId: equipment.equipmentId, suffix: "EQUIP"
                )
            }
            if let img = disconnectPhoto, let data = img.compressedJPEG() {
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
            let newStatus     = computePhotoStatus(for: equipment,
                                                   willHaveEquip: willHaveEquip,
                                                   willHaveIso:   willHaveIso)

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
            // Include the real error so we can diagnose Supabase/network failures
            let detail = (error as? SupabaseError)?.errorDescription ?? error.localizedDescription
            uploadError = "Upload failed (\(detail)). Photos saved locally and queued for your next manual sync."
        }
    }

    @MainActor
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

    // MARK: - Memory Pressure

    /// Called when the OS sends a memory warning. Releases large reloadable images
    /// that were downloaded from Supabase — they will be re-fetched on next selection.
    func handleMemoryWarning() {
        existingEquipPhoto = nil
        existingIsoPhoto   = nil
    }

    // MARK: - Reset

    func resetSession() {
        energyStepTask?.cancel(); energyStepTask = nil
        photoLoadTask?.cancel();  photoLoadTask  = nil
        rebuildTask?.cancel();    rebuildTask    = nil
        selectedEquipment    = nil
        equipmentPhoto       = nil
        disconnectPhoto      = nil
        existingEquipPhoto   = nil
        existingIsoPhoto     = nil
        generatedPDFData     = nil
        pdfError             = nil
        uploadError          = nil
        savedOffline         = false
        lowStorageWarning    = false
        energySteps          = []
    }

    // MARK: - Private: Photo Status Computation

    /// Single source of truth for photo_status, used by photoTaken(), uploadPhotosAndSave(),
    /// and uploadPhoto(). Respects needsEquipPhoto / needsIsoPhoto flags so equipment that
    /// only requires ONE photo type is correctly marked "complete" (not "partial") once
    /// that single photo is present.
    private func computePhotoStatus(for equipment: Equipment,
                                    willHaveEquip: Bool,
                                    willHaveIso:   Bool) -> String {
        let equipOK = !equipment.needsEquipPhoto || willHaveEquip
        let isoOK   = !equipment.needsIsoPhoto   || willHaveIso
        if equipOK && isoOK             { return "complete" }
        if willHaveEquip || willHaveIso { return "partial"  }
        return "missing"
    }

    // MARK: - Private: Local Photo Reconciliation

    /// If a photo was saved locally but Supabase still reports it as absent
    /// (e.g., the upload failed after the local write), update the in-memory
    /// Equipment flags so the list shows the correct status instead of "missing".
    private func reconcileLocalPhotos(_ items: [Equipment]) -> [Equipment] {
        items.map { item in
            var e = item
            let localEquip = PhotoStorageService.shared.hasLocal(equipment: e, type: .equipment)
            let localIso   = PhotoStorageService.shared.hasLocal(equipment: e, type: .isolation)
            guard (!e.hasEquipPhoto && localEquip) || (!e.hasIsoPhoto && localIso) else { return e }
            if localEquip { e.hasEquipPhoto = true }
            if localIso   { e.hasIsoPhoto   = true }
            // Respect needsEquipPhoto / needsIsoPhoto so items that only need ONE
            // photo type are marked "complete" rather than "partial".
            let equipSatisfied = !e.needsEquipPhoto || e.hasEquipPhoto
            let isoSatisfied   = !e.needsIsoPhoto   || e.hasIsoPhoto
            e.photoStatus = (equipSatisfied && isoSatisfied) ? "complete" : "partial"
            return e
        }
    }

    // MARK: - Private: Disk Cache

    // nonisolated: pure FileManager URL computation, safe from any thread
    private nonisolated static let cacheURL: URL = {
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
        // Cancel any in-flight rebuild so a rapid decommission + restore doesn't
        // leave stale stats if the earlier task finishes after the later one.
        rebuildTask?.cancel()

        // Capture value types before crossing the actor boundary.
        let items   = allEquipment
        let retired = decommissionedIDs

        rebuildTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self, !Task.isCancelled else { return }

            // Active = everything that hasn't been decommissioned.
            // Group ALL items so the equipment list's "show decommissioned" toggle works.
            let active = items.filter { !retired.contains($0.equipmentId) }

            var map: [String: [Equipment]] = [:]
            for eq in items { map[eq.department, default: []].append(eq) }
            let groups = map
                .map { (department: $0.key, items: $0.value.sorted { $0.equipmentId < $1.equipmentId }) }
                .sorted { $0.department < $1.department }

            // Global stats — active items only
            var complete = 0, partial = 0, missing = 0
            // Per-department active stats — sidebar rows read these for O(1) lookup
            var deptActive:   [String: Int] = [:]
            var deptComplete: [String: Int] = [:]
            for eq in active {
                deptActive[eq.department, default: 0] += 1
                switch eq.photoStatus {
                case "complete":
                    complete += 1
                    deptComplete[eq.department, default: 0] += 1
                case "partial":  partial += 1
                default:         missing += 1
                }
            }

            // Freeze mutable accumulators as immutable constants before crossing
            // into MainActor.run (@Sendable closure) — required for Swift 6 correctness.
            let snapComplete     = complete
            let snapPartial      = partial
            let snapMissing      = missing
            let snapDeptActive   = deptActive
            let snapDeptComplete = deptComplete

            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.groupedEquipment    = groups
                self.filteredGroups      = groups
                self.filteredEquipment   = items
                self.countActive         = active.count
                self.countComplete       = snapComplete
                self.countPartial        = snapPartial
                self.countMissing        = snapMissing
                self.deptActiveCounts    = snapDeptActive
                self.deptCompleteCounts  = snapDeptComplete
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

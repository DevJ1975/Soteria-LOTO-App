# Changelog

All notable changes to the LOTO Placard Generator app are documented here.

---

## [1.1] — 2026-04-13

### New Features
- **Camera capture** — Photo slots now offer a menu: "Take Photo" (live camera) or "Choose from Library". Powered by a `CameraPickerView` UIImagePickerController wrapper with automatic simulator fallback.
- **Animated splash screen** — Snak King logo bounces in on app launch with a spring animation on the brand indigo background, then slides up to reveal the equipment list.
- **Energy isolation table** — The placard form now displays real energy step data from Supabase (`loto_energy_steps` table). Each row shows the energy type badge, tag description, isolation procedure, and method of verification. A spinner shows while loading; a placeholder shows if no steps exist yet.
- **Side-by-side photos** — Equipment photo and isolation photo are now displayed side by side (matching the physical placard layout) in both the app form and the generated PDF.
- **Snak King logo in header** — Logo now appears in the yellow header band of both the on-screen placard form and the generated PDF (previously was plain "SNAK KING" text).

### Performance
- **Disk cache for instant startup** — Equipment list is saved to disk after first load. Subsequent launches show the full list instantly from cache, then silently refresh from Supabase in the background. App remains usable even when offline.
- **Background cache rebuild** — Grouped/filtered equipment data is computed on a background thread so the main thread is never blocked.
- **Debounced search** — Search filters are applied with a 300ms debounce to avoid filtering on every keystroke.
- **Background PDF generation** — PDF rendering runs on a detached task so the UI stays responsive.

### Bug Fixes
- **Camera crash fixed** — Added missing `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` permission strings. App was crashing on first camera access.
- **Type-checker timeout** — Extracted nested `ForEach+Section` in `EquipmentListView` into a `@ViewBuilder` helper to resolve Swift compiler timeout error.
- **Deployment target mismatch** — Lowered iOS deployment target from 26.4 to 17.0 to match device OS version.

### Architecture
- **NavigationSplitView** — Upgraded from NavigationStack to a three-column iPad layout: departments sidebar, equipment list, placard form detail.
- **`Equipment` conforms to `Hashable`** — Required for `List(selection:)` and `.tag()` in NavigationSplitView.
- **`EnergyStep` model** — New `Codable+Identifiable` struct mirroring the `loto_energy_steps` Supabase table.
- **Removed dead code** — Deleted `EquipmentData.swift` (hardcoded ID list, no longer needed since Supabase is the data source).

### Supabase
- Table corrected from `equipment` to `loto_equipment`.
- New `loto_energy_steps` table added for energy isolation procedure data (one row per energy source per equipment).

---

## [1.0] — 2026-04-01

### Initial Release
- SwiftUI iPad app for Snak King LOTO placard generation.
- Connects to Supabase for equipment data (701 machines).
- Placard form styled to match the physical Snak King LOCKOUT/TAGOUT PROCEDURE format.
- PDF generation using `UIGraphicsPDFRenderer` (US Letter landscape).
- PhotosPicker for equipment and isolation point photos.
- Upload photos and generated PDF back to Supabase Storage.
- Offline draft persistence via `FileManager` + `Codable`.
- No external dependencies — plain `URLSession` for all Supabase API calls.

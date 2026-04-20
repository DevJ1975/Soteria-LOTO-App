# Claude Prompt — Equipment List Page (Web App)

> Build the **Equipment List page** for a LOTO (Lockout/Tagout) safety compliance admin dashboard.
>
> Stack: **Next.js 16 (App Router), React 19, TypeScript 5, Tailwind CSS v4, shadcn/ui v4, Supabase JS v2, Lucide React**. Follow existing project conventions. Do not install new dependencies.
>
> ---
>
> ## Data Source — Supabase Table: `loto_equipment`
>
> ```ts
> interface Equipment {
>   id:                 string       // uuid
>   equipment_id:       string       // e.g. "321-MX-01"
>   description:        string       // e.g. "321-MX-01 (Shaffer Masa Mixer - Line 321)"
>   department:         string       // e.g. "Mixers"
>   prefix:             string       // e.g. "321"
>   has_equip_photo:    boolean
>   has_iso_photo:      boolean
>   photo_status:       'missing' | 'partial' | 'complete'
>   needs_equip_photo:  boolean
>   needs_iso_photo:    boolean
>   needs_verification: boolean
>   verified:           boolean
>   verified_date:      string | null
>   verified_by:        string | null
>   equip_photo_url:    string | null
>   iso_photo_url:      string | null
>   placard_url:        string | null
>   notes:              string | null
>   notes_es:           string | null
>   spanish_reviewed:   boolean
>   created_at:         string | null
>   updated_at:         string | null
> }
> ```
>
> Fetch all equipment on mount:
>
> ```ts
> const { data, error } = await supabase
>   .from('loto_equipment')
>   .select('*')
>   .order('equipment_id', { ascending: true })
> ```
>
> **Derived helper — `shortName`:** Extract text inside the last set of parentheses in `description`.
> e.g. `"321-MX-01 (Shaffer Masa Mixer)"` → `"Shaffer Masa Mixer"`.
> If no parentheses, return `description` as-is.
>
> ---
>
> ## Status Colors
>
> Use these consistently everywhere a status is shown:
>
> | Status | Color |
> |---|---|
> | `complete` | Green |
> | `partial` | Amber / Yellow |
> | `missing` | Red |
> | Decommissioned | Gray (muted) |
>
> ---
>
> ## Page Layout — Three-Panel
>
> ```
> ┌─────────────────┬──────────────────────────┬────────────────┐
> │  Department     │  Equipment List           │  Detail Panel  │
> │  Sidebar        │  (middle)                 │  (right)       │
> │  (fixed width)  │                           │                │
> └─────────────────┴──────────────────────────┴────────────────┘
> ```
>
> On smaller screens collapse to a two-panel or single-panel layout. Match whatever responsive pattern is already used in the project.
>
> ---
>
> ## Panel 1 — Department Sidebar
>
> ### Completion Summary Card (top of sidebar)
>
> Show overall stats across **active** (non-decommissioned) equipment only:
>
> - Large progress bar showing `complete / total_active`
> - Percentage complete (e.g. `67%`)
> - Remaining count (e.g. `"14 remaining"`)
> - Three stat pills in a row:
>   - **Missing** (red) — count of `photo_status === 'missing'`
>   - **Partial** (amber) — count of `photo_status === 'partial'`
>   - **Complete** (green) — count of `photo_status === 'complete'`
>
> ### "All Equipment" Row
>
> - Selects all departments (clears department filter)
> - Shows total active equipment count as a badge
>
> ### Department List
>
> One row per department, sorted alphabetically. Each row shows:
>
> - Department name with a building icon
> - `complete / total` count (active only, e.g. `"8/12"`)
> - A thin progress bar (green when 100%, brand color otherwise)
> - If the department has been signed off: show a green checkmark seal icon + `"Signed off by [name]"` beneath the progress bar
>
> **Context menu on each department row (right-click or three-dot button):**
> - `Sign Off Department…` / `Update Sign-Off…` (if already signed)
> - `Clear Sign-Off` (destructive, only if signed)
> - Divider
> - `Rename Department…` → opens an inline dialog pre-filled with the current name; on confirm, runs a bulk PATCH:
>   ```ts
>   supabase.from('loto_equipment').update({ department: newName }).eq('department', oldName)
>   ```
>   Update local state immediately on success without a full refetch.
>
> ### Sidebar Toolbar / Actions
>
> Buttons at the top of the sidebar:
> - **Import from CSV** → opens the CSV import modal (see separate prompt)
> - **Refresh** → re-fetches all equipment from Supabase
>
> ---
>
> ## Panel 2 — Equipment List (middle)
>
> ### Search Bar
>
> Debounced search (300ms) filtering on `equipment_id` and `description` (case-insensitive).
>
> ### Filter Chips (horizontal scrollable row)
>
> Pill-shaped filter buttons. Show count in parentheses. Active chip is filled with its status color:
>
> | Chip | Filter logic |
> |---|---|
> | All | No filter |
> | Needs Photo | `(needs_equip_photo && !has_equip_photo) \|\| (needs_iso_photo && !has_iso_photo)` |
> | Missing | `photo_status === 'missing'` |
> | Partial | `photo_status === 'partial'` |
> | Complete | `photo_status === 'complete'` |
>
> ### Sort Options
>
> Dropdown or toggle:
> - **Equipment ID** (default, alphabetical)
> - **Status** (missing first → partial → complete)
>
> ### Show / Hide Decommissioned Toggle
>
> Button that toggles visibility of decommissioned items. When shown, decommissioned items appear at the bottom of each group, visually muted (50% opacity, strikethrough on equipment ID).
>
> ### Equipment Rows
>
> Grouped by department with a section header showing `DEPARTMENT NAME (count)`.
>
> Each row contains:
>
> ```
> ● [Equipment ID]  [DECOMMISSIONED badge?]  [🚩 flag?]
>   Short name / description
>                                    [X/Y photos]  [⚠ offline?]
>                                    [Missing | Partial | Complete pill]
>                                    [✓ verified?]
> ```
>
> - **Status dot** (colored circle, left side) — gray if decommissioned
> - **Equipment ID** — monospaced bold font, brand color; strikethrough + gray if decommissioned
> - **DECOMMISSIONED badge** — small gray capsule pill, only when decommissioned
> - **Flag indicator** — amber flag icon (session-only, not persisted)
> - **Short name** — secondary text below the ID, truncated to one line
> - **Photo count** — `"X/Y"` where X = photos captured, Y = photos needed; green if complete
> - **Status pill** — `Missing`, `Partial`, or `Complete` with matching background tint
> - **Verified badge** — green checkmark seal if `verified === true`
>
> **Row actions (hover reveal or right-click context menu):**
> - **Decommission / Restore** — toggles a local-only decommissioned state (stored in component state, not persisted to Supabase). Active items can be decommissioned; decommissioned items can be restored.
> - **Flag / Unflag** — session-only follow-up flag (not persisted)
>
> **On row click:** open the detail panel for that equipment item.
>
> ---
>
> ## Panel 3 — Detail Panel (right)
>
> When no equipment is selected, show an empty state with a placeholder message.
>
> When equipment is selected, show a read-only detail card with:
> - Equipment ID and full description
> - Department and prefix
> - Photo status pill
> - Equipment photo (if `equip_photo_url` is set) — click to open full size
> - Isolation photo (if `iso_photo_url` is set) — click to open full size
> - Placard PDF link (if `placard_url` is set)
> - Notes (if any)
> - Verified status with date and verifier name
> - Spanish reviewed status
>
> ---
>
> ## TypeScript Types
>
> ```ts
> type PhotoStatus = 'missing' | 'partial' | 'complete'
>
> type StatusFilter = 'all' | 'needsPhoto' | 'missing' | 'partial' | 'complete'
> type SortOrder   = 'equipmentId' | 'status'
>
> interface DepartmentStats {
>   department:     string
>   totalActive:    number
>   completeCount:  number
>   progress:       number   // 0–1
>   signedOff:      boolean
>   signedOffBy:    string | null
> }
> ```
>
> ---
>
> ## Performance Notes
>
> - Compute department stats once from the full equipment array and memoize with `useMemo` — do not re-filter per department on every render.
> - Debounce the search input (300ms) before applying the filter.
> - Only active (non-decommissioned) items count toward stats and progress bars.
>
> ---
>
> ## File Structure
>
> Follow the existing App Router convention. Suggested:
>
> ```
> app/equipment/page.tsx            ← main page
> components/equipment/
>   EquipmentList.tsx               ← middle panel
>   EquipmentRow.tsx                ← individual row
>   DepartmentSidebar.tsx           ← left panel
>   DepartmentRow.tsx               ← individual dept row
>   EquipmentDetail.tsx             ← right panel
>   FilterChips.tsx                 ← status filter chips
> lib/equipment.ts                  ← Supabase fetch + helper functions
> ```
>
> Write clean TypeScript — no `any` types, no `// @ts-ignore`. Use `'use client'` only where needed.

# Claude Prompt — Status Report, CSV Export & Add Equipment (Web App)

> Add three new features to the LOTO admin dashboard. The backend is **Supabase JS v2**, frontend is **Next.js 16 (App Router), React 19, TypeScript 5, Tailwind CSS v4, shadcn/ui v4, Lucide React, pdf-lib** (already installed). Follow existing project conventions. Do not install new dependencies.
>
> All three features are accessible from the equipment list toolbar (the `⋯` menu or equivalent action bar).
>
> ---
>
> ## Feature 1 — Placard Status Report (PDF)
>
> Generate and download a multi-page PDF status report using **pdf-lib** (already in the project).
>
> ### Page 1 — Executive Summary
>
> - **Header band** (yellow background, navy text): "LOTO PLACARD STATUS REPORT", facility name "Snak King", and current date/time
> - **Stats row** — five boxes side-by-side, each with a large bold number and a label:
>   - Total Active (brand navy)
>   - Complete (green)
>   - Partial (amber)
>   - Missing (red)
>   - Decommissioned (gray)
> - **Progress bar** — shows `complete / total_active` percentage, filled green when 100%, brand color otherwise. Label inside: `"X% complete — Y of Z placards done"`
> - **Department breakdown table**:
>   - Columns: `Department | Total | Complete | Partial | Missing | % | Signed Off`
>   - One row per department, sorted alphabetically
>   - Rows with 100% completion get a light green background tint
>   - Signed-off departments show `✓ [supervisor name]` in green in the last column
>
> ### Page 2+ — Equipment List (paginated)
>
> - **Column header row** (navy background, white text): `Equipment ID | Description | Department | Status | Verified`
> - One row per **active** (non-decommissioned) equipment item, sorted by `equipment_id`
> - Status column: colored text — green for `complete`, amber for `partial`, red for `missing`
> - Verified column: `✓` in green or `—` in gray
> - Alternating row background (`white` / very light gray)
> - Footer on each page: `"LOTO Status Report — [date/time]"` left, `"Page X of Y"` right
>
> ### UX
>
> - Trigger via a **"Status Report"** button in the equipment list action bar
> - Show a loading spinner while generating
> - On completion, trigger an automatic browser download of `LOTO_Status_Report_YYYY-MM-DD.pdf`
> - On error, show the error message inline
>
> ### Data needed from Supabase
>
> ```ts
> // All equipment (already loaded on the equipment list page — reuse existing state)
> // Department sign-off data (if stored in a separate table, fetch it; otherwise use local state)
>
> // Compute these from the equipment array:
> const active        = equipment.filter(eq => !decommissioned.has(eq.equipment_id))
> const countComplete = active.filter(eq => eq.photo_status === 'complete').length
> const countPartial  = active.filter(eq => eq.photo_status === 'partial').length
> const countMissing  = active.filter(eq => eq.photo_status === 'missing').length
>
> // Per-department stats — compute with a single pass:
> const deptStats = departments.map(dept => {
>   const rows     = active.filter(eq => eq.department === dept)
>   const complete = rows.filter(eq => eq.photo_status === 'complete').length
>   const partial  = rows.filter(eq => eq.photo_status === 'partial').length
>   const missing  = rows.filter(eq => eq.photo_status === 'missing').length
>   const pct      = rows.length > 0 ? Math.round(complete / rows.length * 100) : 0
>   return { dept, total: rows.length, complete, partial, missing, pct }
> })
> ```
>
> ---
>
> ## Feature 2 — Export Equipment CSV
>
> Generate and download a CSV of all equipment (active + decommissioned) from the existing in-memory equipment state — **no additional Supabase fetch needed**.
>
> ### CSV Columns
>
> ```
> equipment_id, description, department, prefix, photo_status,
> has_equip_photo, has_iso_photo, needs_equip_photo, needs_iso_photo,
> verified, verified_by, verified_date, decommissioned, notes
> ```
>
> ### Rules
>
> - Sort rows by `equipment_id` ascending
> - Wrap any field containing a comma, double-quote, or newline in double-quotes; escape internal double-quotes as `""`
> - Boolean fields: `"true"` / `"false"`
> - Null/empty optional fields: empty string (no quotes needed)
> - File name: `LOTO_Equipment_Export_YYYY-MM-DD.csv`
>
> ### UX
>
> - Trigger via **"Export Equipment CSV"** button in the action bar
> - Generates the CSV string client-side, creates a `Blob`, and triggers a browser download immediately — no loading state needed
> - No modal or confirmation required
>
> ### TypeScript helper
>
> ```ts
> function csvEscape(value: string): string {
>   if (value.includes(',') || value.includes('"') || value.includes('\n')) {
>     return `"${value.replace(/"/g, '""')}"`
>   }
>   return value
> }
>
> function exportEquipmentCSV(equipment: Equipment[], decommissioned: Set<string>): void {
>   const headers = [
>     'equipment_id','description','department','prefix','photo_status',
>     'has_equip_photo','has_iso_photo','needs_equip_photo','needs_iso_photo',
>     'verified','verified_by','verified_date','decommissioned','notes'
>   ]
>   const rows = [...equipment]
>     .sort((a, b) => a.equipment_id.localeCompare(b.equipment_id))
>     .map(eq => [
>       csvEscape(eq.equipment_id),
>       csvEscape(eq.description),
>       csvEscape(eq.department),
>       csvEscape(eq.prefix),
>       eq.photo_status,
>       String(eq.has_equip_photo),
>       String(eq.has_iso_photo),
>       String(eq.needs_equip_photo),
>       String(eq.needs_iso_photo),
>       String(eq.verified),
>       csvEscape(eq.verified_by   ?? ''),
>       csvEscape(eq.verified_date ?? ''),
>       String(decommissioned.has(eq.equipment_id)),
>       csvEscape(eq.notes ?? '')
>     ].join(','))
>
>   const csv  = [headers.join(','), ...rows].join('\n')
>   const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
>   const url  = URL.createObjectURL(blob)
>   const a    = document.createElement('a')
>   a.href     = url
>   a.download = `LOTO_Equipment_Export_${new Date().toISOString().slice(0,10)}.csv`
>   a.click()
>   URL.revokeObjectURL(url)
> }
> ```
>
> ---
>
> ## Feature 3 — Add Equipment (Blank Placard)
>
> A modal/dialog form to add a single new equipment item directly to Supabase.
>
> ### Form Fields
>
> | Field | Type | Required | Notes |
> |---|---|---|---|
> | Equipment ID | Text input | Yes | Validate uniqueness against existing equipment in state — show inline error if duplicate |
> | Description | Text input | Yes | Full machine description |
> | Department | Select/combobox | Yes | Populated from existing unique department names; also allow typing a new department name |
> | Prefix | Text input | No | Auto-derived from Equipment ID (everything before the first `-`); user can override |
> | Needs Equipment Photo | Toggle/checkbox | No | Default `true` |
> | Needs Isolation Photo | Toggle/checkbox | No | Default `true` |
> | Notes | Textarea | No | Optional |
>
> ### Validation
>
> - **Equipment ID**: non-empty + not already in the equipment list (check client-side, show error inline as user types — debounced 300ms)
> - **Description**: non-empty
> - **Department**: non-empty
> - **Prefix**: auto-derive from Equipment ID onChange if field is empty; allow manual edit
> - Save button is disabled until all required fields are valid
>
> ### Supabase Insert
>
> ```ts
> const { error } = await supabase.from('loto_equipment').insert({
>   equipment_id:       trimmedId,
>   description:        trimmedDesc,
>   department:         trimmedDept,
>   prefix:             trimmedPrefix,
>   needs_equip_photo:  needsEquipPhoto,
>   needs_iso_photo:    needsIsoPhoto,
>   notes:              notes.trim() || null,
>   // Always hard-code these — never let the form override them:
>   has_equip_photo:    false,
>   has_iso_photo:      false,
>   photo_status:       'missing',
>   needs_verification: false,
>   verified:           false,
>   spanish_reviewed:   false,
> })
> ```
>
> ### UX
>
> - Trigger via **"Add Equipment"** button in the action bar
> - Use shadcn/ui `Dialog` (or whichever modal pattern exists in the project)
> - While saving: disable form fields and show a spinner on the Save button
> - On success: close the dialog and update the local equipment state immediately (optimistic or via refetch — match whichever pattern is used elsewhere in the project)
> - On error: show the Supabase `error.message` inside the dialog — do not close it
>
> ---
>
> ## Action Bar / Menu Integration
>
> Add all three to the existing equipment list toolbar. Suggested order inside the `⋯` menu or action bar (match the existing button style):
>
> ```
> [existing buttons...]
> ─────────────────────
> 📊  Status Report        → generates + downloads PDF
> ⬆   Export Equipment CSV → generates + downloads CSV immediately
> ➕  Add Equipment        → opens Add Equipment dialog
> ─────────────────────
> [existing buttons...]
> ```
>
> ---
>
> ## TypeScript Types (for reference)
>
> ```ts
> interface Equipment {
>   id:                 string
>   equipment_id:       string
>   description:        string
>   department:         string
>   prefix:             string
>   has_equip_photo:    boolean
>   has_iso_photo:      boolean
>   photo_status:       'missing' | 'partial' | 'complete'
>   needs_equip_photo:  boolean
>   needs_iso_photo:    boolean
>   needs_verification: boolean
>   verified:           boolean
>   verified_date:      string | null
>   verified_by:        string | null
>   notes:              string | null
>   spanish_reviewed:   boolean
>   created_at:         string | null
>   updated_at:         string | null
> }
>
> interface DeptStats {
>   dept:     string
>   total:    number
>   complete: number
>   partial:  number
>   missing:  number
>   pct:      number
>   signedOff: boolean
>   signedOffBy: string | null
> }
> ```
>
> ---
>
> ## File Structure
>
> Follow the existing project conventions. Suggested:
>
> ```
> lib/report.ts              ← PDF generation logic (pdf-lib)
> lib/export.ts              ← CSV export helper
> components/equipment/
>   StatusReportButton.tsx   ← button + generation trigger
>   ExportCsvButton.tsx      ← button + download trigger
>   AddEquipmentDialog.tsx   ← modal form
> ```
>
> Write clean TypeScript — no `any` types, no `// @ts-ignore`. Use `'use client'` only where needed.

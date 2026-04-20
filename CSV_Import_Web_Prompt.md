# Claude Prompt — CSV Bulk Equipment Import (Web App)

> I'm building a web admin dashboard for a LOTO (Lockout/Tagout) safety compliance app. The backend is **Supabase JS v2**. The frontend is **Next.js 16 (App Router), React 19, TypeScript 5, Tailwind CSS v4, and shadcn/ui v4**. Icons are from **Lucide React**.
>
> Build a **CSV bulk equipment import feature** as a new page or modal. Follow existing project conventions exactly — App Router file structure, shadcn/ui components, Tailwind v4 classes, and TypeScript throughout. Do not install any new dependencies.
>
> ---
>
> ## Supabase Table: `loto_equipment`
>
> Columns relevant to import:
>
> ```ts
> equipment_id: string        // unique, required
> description:  string        // required
> department:   string        // required
> prefix:       string        // required — auto-derive from equipment_id if column absent
> needs_equip_photo: boolean  // optional, default true
> needs_iso_photo:   boolean  // optional, default true
> notes:        string | null // optional
> ```
>
> Always hard-code these on insert — never let the CSV override them:
>
> ```ts
> has_equip_photo:    false
> has_iso_photo:      false
> photo_status:       'missing'
> needs_verification: false
> verified:           false
> spanish_reviewed:   false
> ```
>
> The `id` column is `uuid` with `gen_random_uuid()` default — omit it from the INSERT payload.
>
> ---
>
> ## CSV Format
>
> Header row required. Column names are **case-insensitive**; spaces and underscores are interchangeable.
>
> **Required columns:** `equipment_id`, `description`, `department`
> **Optional columns:** `prefix`, `needs_equip_photo`, `needs_iso_photo`, `notes`
>
> - If `prefix` is absent, auto-derive: everything in `equipment_id` before the first `-` (e.g. `321-MX-01` → `321`).
> - Boolean columns accept `true/false`, `yes/no`, `1/0` (case-insensitive). Default to `true` if the column is absent entirely.
> - Skip blank rows silently.
> - Parser must be **RFC 4180 compliant**: quoted fields, commas inside quotes, `""` escaped quotes, `\r\n` and `\n` line endings.
> - Encoding: UTF-8 preferred, Latin-1 fallback (covers Excel `.csv` exports).
>
> Example:
>
> ```csv
> equipment_id,description,department,prefix,needs_equip_photo,needs_iso_photo,notes
> 321-MX-01,Main Disconnect Switch,Maintenance,321,true,true,
> 321-MX-02,Motor Control Center,Maintenance,321,true,true,
> 450-PMP-01,Feed Pump Motor,Operations,450,true,false,Check torque specs
> 450-VLV-01,Isolation Valve,Operations,450,false,true,Manual valve only
> ```
>
> ---
>
> ## UX — 3-Step Flow
>
> Use shadcn/ui `Card`, `Button`, `Badge`, `Table`, and `Progress` (or equivalent) components. No new dependencies.
>
> **Step 1 — Upload**
> - Drag-and-drop zone + "Choose file" button. Accept `.csv` and `.txt`.
> - Parse entirely client-side (no server round-trip for parsing).
> - On file select, fetch all existing `equipment_id` values from Supabase for duplicate detection:
>   ```ts
>   supabase.from('loto_equipment').select('equipment_id')
>   ```
>
> **Step 2 — Preview**
> Display a summary bar with three counts, then a scrollable table of all parsed rows:
> - **New** (green) — `equipment_id` not in Supabase → will be imported
> - **Existing** (muted) — already in Supabase → will be skipped
> - **Invalid** (red) — missing a required field → show reason inline per row
>
> Import button is disabled if there are zero New rows.
>
> **Step 3 — Result**
> After import show: `"Imported X new items, skipped Y existing."` with a button to refresh the equipment list.
>
> ---
>
> ## Supabase Insert
>
> POST only the New rows using the Supabase JS client, in batches of 100 (plain INSERT, not upsert):
>
> ```ts
> const { error } = await supabase
>   .from('loto_equipment')
>   .insert(batch)   // batch is NewEquipmentRow[]
> ```
>
> If any batch errors, surface the Supabase `error.message` to the user — do not swallow it silently.
>
> ---
>
> ## TypeScript Types
>
> ```ts
> interface ParsedRow {
>   equipmentId:     string
>   description:     string
>   department:      string
>   prefix:          string
>   needsEquipPhoto: boolean
>   needsIsoPhoto:   boolean
>   notes:           string | null
>   status: 'new' | 'existing' | 'invalid'
>   error?: string
> }
>
> interface NewEquipmentRow {
>   equipment_id:       string
>   description:        string
>   department:         string
>   prefix:             string
>   needs_equip_photo:  boolean
>   needs_iso_photo:    boolean
>   notes:              string | null
>   has_equip_photo:    false
>   has_iso_photo:      false
>   photo_status:       'missing'
>   needs_verification: false
>   verified:           false
>   spanish_reviewed:   false
> }
> ```
>
> ---
>
> ## File Structure
>
> Follow the existing App Router convention. Suggested location:
>
> ```
> app/import/page.tsx          ← route page (or add as a modal if a modal pattern exists)
> components/csv-import/       ← sub-components if needed
> ```
>
> Write clean, idiomatic TypeScript with no `any` types and no `// @ts-ignore`. Export the page as a default export. Use `'use client'` only where necessary (file reading and Supabase calls).

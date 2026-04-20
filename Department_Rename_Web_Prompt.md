# Claude Prompt — Department Rename Feature (Web App)

> I need to add a **department rename feature** to the admin dashboard. The backend is **Supabase JS v2**, frontend is **Next.js 16 (App Router), React 19, TypeScript 5, Tailwind CSS v4, shadcn/ui v4**, icons from **Lucide React**. Follow existing project conventions. Do not install new dependencies.
>
> ---
>
> ## What It Does
>
> A manager can rename a department directly from the department list UI. Renaming updates **every equipment row** in that department in a single Supabase PATCH call, then reflects instantly in the UI without a full page reload.
>
> ---
>
> ## Supabase Operation
>
> Single bulk PATCH — filter by old department name, set new name:
>
> ```ts
> const { error } = await supabase
>   .from('loto_equipment')
>   .update({ department: newName })
>   .eq('department', oldName)
> ```
>
> - Do **not** use upsert.
> - If Supabase returns an error, surface `error.message` to the user — do not swallow it.
> - On success, update the local state/cache immediately so the UI reflects the change without a full refetch.
>
> ---
>
> ## UX Flow
>
> 1. Each department row has a **context menu or action button** (three-dot menu, right-click, or hover reveal — match the existing pattern in the project).
> 2. Clicking **"Rename Department…"** opens an **inline dialog or modal** (use shadcn/ui `Dialog` or `AlertDialog` — match whichever pattern already exists in the project).
> 3. The input field is **pre-filled** with the current department name.
> 4. User edits the name and clicks **Rename**.
> 5. While the request is in-flight, the Rename button shows a **loading state** and is disabled to prevent double-submit.
> 6. On success: close the dialog, update the department name everywhere it appears in the UI instantly (equipment list, stats, charts, etc.).
> 7. On error: show the Supabase error message **inside the dialog** (do not close it) so the user can retry or cancel.
> 8. **Cancel** closes the dialog with no changes.
>
> ---
>
> ## Validation
>
> - Trim whitespace from the new name before submitting.
> - Disable the Rename button if the trimmed value is empty or unchanged from the original.
> - Show an inline validation message if the user tries to submit an empty name.
>
> ---
>
> ## TypeScript
>
> Add a reusable async function (co-locate with other Supabase helpers or in a `lib/departments.ts` file):
>
> ```ts
> /**
>  * Renames all equipment rows belonging to `oldName` to `newName`.
>  * Returns the number of rows updated, or throws on error.
>  */
> export async function renameDepartment(
>   oldName: string,
>   newName: string
> ): Promise<void> {
>   const trimmed = newName.trim()
>   if (!trimmed || trimmed === oldName) return
>
>   const { error } = await supabase
>     .from('loto_equipment')
>     .update({ department: trimmed })
>     .eq('department', oldName)
>
>   if (error) throw new Error(error.message)
> }
> ```
>
> Use clean TypeScript — no `any` types, no `// @ts-ignore`.
>
> ---
>
> ## Local State Update (important)
>
> After a successful rename, update the local equipment state so every reference to the old department name is replaced with the new one — **without triggering a full refetch**:
>
> ```ts
> setEquipment(prev =>
>   prev.map(eq =>
>     eq.department === oldName ? { ...eq, department: newName.trim() } : eq
>   )
> )
> ```
>
> Also update any derived state that holds department names (e.g. the department list, chart labels, filter dropdowns).
>
> ---
>
> ## Placement
>
> Add the rename action wherever departments are listed — for example:
> - The department sidebar or list page
> - A department settings/management section if one exists
>
> Match the exact interaction pattern already used in the project for other row-level actions (edit, delete, etc.).

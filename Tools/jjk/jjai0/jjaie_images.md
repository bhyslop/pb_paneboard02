# JJK Image Viewing & Updating (unfurl)

These are the tools for VIEWING and UPDATING SVG/PNG files — diagrams and rendered images — on the diagram viewer.

When the user says "unfurl" (put an image on the diagram viewer), invoke the **`vvx_render`** MCP tool — `mcp__vvx__vvx_render`, a sibling of the gallops dispatcher, NOT a `jjx_*` command. It takes no model.

Params:
- `light` (required) — path to the image to display (SVG or raster).
- `dark` (optional) — path to a dark variant. When supplied it is **transported as the pair's second payload**; the viewer holds both and the operator toggles with `d`/`l`. The viewer never derives one from the other, so pass both paths when you have a light/dark pair (e.g. rbm's README `<picture>` SVGs). Omit it for a single-variant image.
- `anew` (optional boolean) — **you set this from conversational intent**, per the heuristic below.

**The `anew` heuristic** (the judgment you legitimately hold — decide alike every time so the surface is consistent):
- `anew: true` — a fresh look (fit-to-window). Use when the image is **new or different** from what is up, or the user explicitly asks for a fresh/refit view.
- `anew: false` — an iteration at the viewer's **held zoom + pan**. Use when the user is **tweaking the same image already on the viewer** (a re-render after an edit). Retaining the viewport is the point: the operator stays zoomed where they were looking.
- When unsure, omit it — the tool defaults to a fresh look (fit-to-window).

The push is **best-effort / fail-soft**: an absent or unreachable viewer comes back as a soft notice (not an error). Bringing the viewer up is paneboard's job (it conducts the window), so on a soft-fail, relay the notice — do not retry in a loop.

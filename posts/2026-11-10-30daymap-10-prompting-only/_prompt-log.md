# Day 10 prompt log

Verbatim prompts from Sean, in order. Claude wrote every line of code; Sean made no hand edits.
Assistant replies are summarized, not quoted.

1. **Prompt:** "Let's work on Day 10 of the mapping challenge. New branch for it."
   **Reply:** Found an existing `feat/30daymap-day10-prompting-only` branch with mapgl/Mapbox setup; fast-forwarded it to `origin/master`. Asked what "prompting only" should mean and which topic. Sean chose "prompt log"; topic open.
2. **Prompt:** "Ehhhhhhhh What if we relax the EPA side of things."
   **Reply:** Offered non-EPA ideas: CNEOS fireballs, found meteorites, Great Lakes shipwrecks over bathymetry, eclipse paths, submarine cables.
3. **Prompt:** (quoting the shipwrecks idea) "Perfect. Just in time for the Edmund Fitzgerald."
   **Reply:** Scoped to Lake Superior (Fitzgerald sank there 1975-11-10). Checked sources: NCEI Lake Superior bathymetry (GeoTIFF); NOAA ENC wreck points (33, mostly unnamed, retired AWOIS); Wikidata wrecks in a Superior bounding box (~57 named, CC0).
4. **Prompt:** "A and B? Combo?"
   **Reply:** Proposed terrain floor plus translucent hex water columns that fade on zoom-in. Wrote a plan and sent it to a
   code-review agent, which caught three blockers: mapgl drops `tiles`/`encoding` on raster-dem sources (fixed with an
   `onRender` JavaScript hook), extrusion heights are not scaled by terrain exaggeration (height = depth × 30), and a
   plain `prompt-log.md` would be listed as a blog post (renamed `_prompt-log.md`, included).
   **Errors and corrections:** AWS terrarium tiles turned out flat over the lake (no bathymetry), so tiles are built
   from NCEI. `subset()` on a terra polygon failed ("'subset' must be logical"); rewritten as a logical index. A
   depth rule for filtering wrecks dropped real nearshore wrecks (*America*, *Lafayette*) and kept museum ships in
   harbors; replaced with six explicit exclusions, each with a reason.
5. **Prompt:** "Tool loaded."
   **Reply:** (A preview tool had been loaded; it cannot load tiled terrain, so the post itself is rendered for review.)
6. **Prompt:** "Eh? What's the difference between day 16 vs the approach for this day for rendering?"
   **Reply:** Explained that both are `mapgl` MapLibre widgets built the same way, but Day 10 also loads 176 terrain tiles
   from files next to the post through a JavaScript hook, so it has to be viewed from a served page.
7. **Prompt:** "Keep the terrain."
   **Reply:** Kept the tiled 3D floor and wrote the Day 10 test.
   **Errors and corrections:** the first test run failed: NOAA's chart service had answered with a "Could not find
   service" error inside an HTTP 200 reply, and the pipeline had saved it as an empty wreck table. Acquisition now
   stops when either service returns no records, and the retried request worked. mapgl warned that extrusions can
   render badly on its default globe projection; switched to Mercator, as Day 16 does.
8. **Prompt:** "Why not render it and then send screenshots back to me?"
   **Reply:** Served the rendered post locally, opened it in a browser and sent screenshots back.
   **Errors and corrections:** the screenshots showed two bugs. The "Fly to" button never responded, because the panel
   is added after the JavaScript hook runs, so the hook found no button to attach to; it now listens for clicks on the
   whole map. MapLibre's control CSS also squeezed the button to 29 px wide. The opening view was moved north and
   closer, because the lake filled only a small strip of the frame.
9. **Prompt:** "Go ahead for both."
   **Reply:** Coloured the floor by depth with MapLibre's built-in `color-relief` layer, reading the same terrain tiles,
   so the depth colour sits on the floor rather than on the columns. Made the columns a single dark blue at 40%
   opacity so the floor shows through them, set a dark sky so the horizon is no longer white, and lowered and moved the
   opening camera so the whole lake fills the frame. The values were tuned live in the browser from screenshots, then
   written into the code.
10. **Prompt:** "Looks good! Save the static PNG, then commit." (and "Yes." to also committing the Mapbox setup notes)
    **Reply:** Cropped a browser screenshot of the opening view to the map, saved it as the post's listing image, and
    committed the post with its test and setup notes.

# Christmas iPad landscape backgrounds — brief for codex

Built-in `image_gen` only. No git commit. Do NOT modify anything under `images/christmas-draft/` (read-only references)
and do not touch any other file except the two outputs below and an appended section in `images/backgrounds/iPad/PROMPTS.md`.

Make ONE landscape recomposition for each of the two confirmed iPhone portrait backgrounds. `view_image` each reference first.
Do not stretch or rotate the portrait image — recompose the same scene for a wide landscape canvas (1536×1024 output is fine;
the app crops it to 4:3, so keep every important object inside the central 4:3 area, x ≈ 85–1451 of 1536).

Shared rules (same as the existing iPad set, see `images/backgrounds/iPad/README.md`):
- Same palette, same pixel size and crisp square pixels as the portrait reference. Max ~24 flat colors, no dithering,
  no anti-aliasing, no blur/glow gradients, no painterly or photo texture. No text, logo, UI, watermark, characters or animals
  (the Santa+reindeer silhouette in B is the only exception).
- Top 30% of the height: calm, nearly empty (timer goes there).
- Wall/floor line (A) or snow horizon (B): ONE straight horizontal line at 72% of the height.
- Flat frontal view, no perspective.

## A → `images/backgrounds/iPad/source/06_Christmas_Eve_iPad_raw.png`
Reference: `images/christmas-draft/backgrounds/xmas_bg_A_eve_room_v2.png` (portrait, 1024×1536).
Same dark burgundy wallpaper with the tiny pattern marks, the pine garland with red/gold ornaments draped across the wall
(extend it across the full width), and the wooden plank floor. The brick fireplace with the warm crackling fire stays
CENTERED horizontally, standing on the 72% floor line, same size relative to the image HEIGHT as in the reference
(do not enlarge it to fill the width). Warm hard-edged light tiles on the floor in front of it. Still dark overall.

## B → `images/backgrounds/iPad/source/07_Snowy_Night_iPad_raw.png`
Reference: `images/christmas-draft/backgrounds/xmas_bg_B_snowy_night_v2.png` (portrait, 1024×1536).
Same deep navy night sky with a few sparse single-pixel stars, the row of dark teal pine silhouettes along the horizon
(extend across the full width), and the pale blue snow ground with soft stepped drifts below the 72% horizon.
The big full moon (same size relative to the image HEIGHT as in the reference) sits at x ≈ 75% of the width,
vertically centered at ≈ 45% of the height — fully visible, below the empty top 30%.
The small near-black silhouette of Santa's sleigh pulled by 3–4 flying reindeer crosses IN FRONT of the moon,
flying to the left, the whole group INSIDE the moon disc (about 80% of the moon's diameter wide). No colors on the silhouette.

Self-check before finishing: both files exist, landscape, top 30% calm, line at 72%, fireplace centered (A),
moon right of center with the whole sleigh inside the disc (B), no text. Append the exact prompts to
`images/backgrounds/iPad/PROMPTS.md` under a new heading "## Christmas (2026-11-07)". Finish by listing the 2 new files.

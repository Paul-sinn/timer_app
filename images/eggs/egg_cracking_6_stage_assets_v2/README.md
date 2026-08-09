# Hatcho Egg Crack Animation — v2

This package fixes the crack continuity between stages 3 and 4.

## Frame order

1. `fullegg.png`
2. `firstcrack_egg.png`
3. `secondcrack_egg.png`
4. `thirdcrack_egg.png` — revised
5. `fourthcrack_egg.png`
6. `abouttocrack_egg.png`

All final assets are 941×1672 RGBA PNGs with transparent backgrounds and the same egg position, size, and baseline.

The revised stage 4 preserves stage 3's central Y-shaped crack and extends it from its existing endpoints, preventing the crack pattern from popping between frames.

Suggested playback timing:

- Stages 1–2: 180 ms each
- Stage 3: 220 ms
- Stage 4: 200 ms
- Stage 5: 170 ms
- Stage 6: 140 ms, then transition into the golden pre-hatch charge

# Hatcho iPad Pixel Backgrounds

아이폰용 픽셀 배경 5종과 같은 팔레트·무늬를 사용한 가로 4:3 배경입니다.

| Mode | File | Palette |
| --- | --- | --- |
| Dark | 01_Midnight_Navy.png | Midnight navy / slate blue / muted tan |
| Dark | 02_Cocoa_Night.png | Dark cocoa wall, mint pixel pattern (2026-10-23 교체 — 원본 업로드는 ../source/) |
| Light | 03_Butter_Yellow.png | Butter yellow / warm cream / pale honey |
| Light | 04_Mint_Cream.png | Pastel mint / warm ivory / muted sage |
| Light | 05_Lavender_Milk.png | Pale lavender / lilac / warm ivory |
| Dark | 06_Christmas_Eve.png | 크리스마스 월드 — 벽난로 방 (원본 `source/06_Christmas_Eve_iPad_raw.png`) |
| Dark | 07_Snowy_Night.png | 크리스마스 월드 — 보름달·산타 썰매 눈 덮인 밤 (원본 `source/07_Snowy_Night_iPad_raw.png`) |

크리스마스 2장(2026-11-07)은 codex 내장 image_gen으로 아이폰 v2를 가로로 다시 구성했다(지시서 `BRIEF_XMAS.md`, 프롬프트 `PROMPTS.md`).
가공은 `scripts/make_christmas_backgrounds.py`가 아이폰 것과 같이 한다: 4:3 자르기 → 480×360 → 24색,
그리고 아이폰 그림의 벽(위)·바닥 색에 채널별로 맞춰서 아이패드를 돌려도(세로=아이폰 그림, 가로=이 그림) 색이 안 튄다.

## Export specification

- Native: 480×360 pixels, horizontal 4:3.
- Export: 1920×1440 pixels, exact 4× nearest-neighbor enlargement.
- Maximum 24 colors per image; corresponding iPhone reference palette reused.
- No dithering; no alpha channel.
- Top 30% (native rows 0–107) is a single flat wall color.
- Straight wall/floor boundary starts at native row 259 (71.944% of height,
  the closest integer grid position to 72%); exported row 1036.
- Same tiny faceless egg, roll-cake spiral, and plus wallpaper motifs.
- No text, characters, animals, UI, furniture or windows.

## Contents

- Native_480x360/: five native-size PNGs.
- PNG_1920x1440/: five 4× PNGs for app use.
- Hatcho_iPad_Pixel_Themes_Preview.png: comparison sheet.
- PROMPTS.md: exact built-in image-generation prompt set.

Built with the built-in image-generation tool using the phone references.
Final exports normalize the pixel grid, align the floor line, clean the flat wall,
remap to each reference palette without dithering, and apply integer enlargement.
Existing iPhone files and app code are unchanged by this iPad asset task.

SwiftUI에서 사용할 때 .interpolation(.none)을 적용하세요.


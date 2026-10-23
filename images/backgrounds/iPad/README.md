# Hatcho iPad Pixel Backgrounds

아이폰용 픽셀 배경 5종과 같은 팔레트·무늬를 사용한 가로 4:3 배경입니다.

| Mode | File | Palette |
| --- | --- | --- |
| Dark | 01_Midnight_Navy.png | Midnight navy / slate blue / muted tan |
| Dark | 02_Cocoa_Night.png | Dark cocoa / mushroom taupe |
| Light | 03_Butter_Yellow.png | Butter yellow / warm cream / pale honey |
| Light | 04_Mint_Cream.png | Pastel mint / warm ivory / muted sage |
| Light | 05_Lavender_Milk.png | Pale lavender / lilac / warm ivory |

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


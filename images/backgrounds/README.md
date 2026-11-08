# Hatcho Pixel Backgrounds — v2

픽셀 캐릭터를 돋보이게 하는 미니멀 배경 5종입니다.
앱 코드 및 테마 전환 기능은 이 패키지에 포함하지 않았습니다.

## Files

| Mode | File | Palette |
| --- | --- | --- |
| Dark | 01_Midnight_Navy.png | Smoky navy, dusty blue-violet, muted gold |
| Dark | 02_Cocoa_Night.png | Warm dark cocoa wall, mint pixel pattern (2026-10-23 교체 — 원본 업로드는 source/) |
| Light | 03_Butter_Yellow.png | Butter yellow, warm cream, pale honey |
| Light | 04_Mint_Cream.png | Pastel mint, warm ivory, muted sage |
| Light | 05_Lavender_Milk.png | Pale lavender, lilac, warm ivory |

- `PNG_1080x1920/`: 앱용 세로 9:16 PNG, 투명도 없음.
- `Native_270x480/`: 같은 디자인의 저해상도 원본.
- `Hatcho_Pixel_Themes_Preview.png`: 5종 비교용 미리보기.
- 최종 파일은 이미지당 최대 24색, 디더링 없음, 정수 4배 최근접 확대.
- 상단 35%는 타이머를 위한 거의 빈 영역입니다.
- 벽과 바닥 경계는 높이 70%에 맞췄습니다.
- 반복 무늬는 얼굴 없는 작은 달걀과 롤케이크입니다. 동물·캐릭터·UI는 없습니다.

## Image-generation prompt set

Generated with the built-in image-generation tool, then exported to an actual
270×480 pixel grid, quantized to at most 24 colors without dithering, and enlarged
4× using nearest-neighbor. Generated originals are retained separately.

Common art direction:

> Cozy pixel art background, vertical 9:16 phone wallpaper. Soft low-contrast
> [theme palette], limited 24-color palette, crisp square pixels, no anti-aliasing.
> Top 35% nearly empty plain area. Simple straight floor/baseboard line at 70%
> height. Tiny widely spaced repeating faceless egg shapes and roll-cake spirals
> as very subtle tone-on-tone wallpaper. Plain floor with restrained plank seams.
> Calm, cute, warm, flat front-facing cozy room. No text, characters, animals,
> UI, furniture, windows, shelves, plants, lamps, pedestal, detailed scenery,
> gradients, blur, bloom, painterly texture, photographic texture, or watermark.

The butter-yellow image establishes the shared layout. The other four images use
it as the layout/style reference and change only the palette according to the
table above. Dark themes are dark enough to support cream UI; light themes are
intended for dark UI lettering. Final UI contrast still needs device testing.

## Integration note

원본 PNG를 JPEG로 바꾸거나 부드러운 필터로 리사이즈하면 픽셀 경계가 흐려집니다.
SwiftUI에서는 `.interpolation(.none)`을 사용하세요. 화면이 9:16보다 길면
`scaledToFill`에서 좌우가 잘릴 수 있으므로 바닥선과 캐릭터의 실제 위치를
실기기에서 맞춰야 합니다. 배경과 기존 캐릭터는 별도 레이어로 유지하세요.

## 크리스마스 월드 배경 (2026-11-07)

월드 = 캐릭터 + 배경 + BGM 한 세트. 크리스마스 월드를 고르면 홈 등 전 화면 배경이 아래 둘 중 하나로 바뀌고
(설정 > Theme·홈 붓 버튼에는 이 둘만 보임), 기본 월드로 돌아가면 원래 고른 배경으로 돌아간다. 둘 다 다크.

| 파일 | 앱 에셋 | 원본 |
| --- | --- | --- |
| 06_Christmas_Eve.png | BackgroundChristmasEve(+Wide) | `source/06_Christmas_Eve_iPhone_raw.png` = 초안 `xmas_bg_A_eve_room_v2.png` (벽난로 방) |
| 07_Snowy_Night.png | BackgroundSnowyNight(+Wide) | `source/07_Snowy_Night_iPhone_raw.png` = 초안 `xmas_bg_B_snowy_night_v2.png` (보름달·산타 썰매) |

- 가공은 손으로 하지 말고 `scripts/make_christmas_backgrounds.py` 한 번 실행:
  9:16 가운데 자르기 → 270×480 격자 → 24색·디더 없음 → 앱 에셋 + `PNG_1080x1920/` 4배 보관본.
- **눈 덮인 밤의 눈밭은 원본보다 어둡다(달빛 눈밭).** 원본 눈밭이 너무 밝아 그 위 크림색 글자
  ("Hatching progress")가 대비 1.4:1로 안 읽혔다. 스크립트가 바닥만 같은 색조로 낮춘다
  (기준 = 기존 Cocoa 바닥과 같은 3:1, `FLOOR_MAX_LUM`). `AppThemeTests`가 앱에 들어간 그림으로 다시 검사한다.
- **원본 바꾸기**(예: 눈 덮인 밤 v3 — 요즘 아이폰은 가운데 약 69%만 보여 v2는 썰매 오른쪽이 잘린다):
  ```bash
  cp images/christmas-draft/backgrounds/xmas_bg_B_snowy_night_v3.png images/backgrounds/source/07_Snowy_Night_iPhone_raw.png
  uv run --with numpy --with pillow python scripts/make_christmas_backgrounds.py
  ```
  출력의 `top color`가 `AppTheme.pageBackground`와 다르면 그 값으로 고친다(`AppThemeTests.pageBackgroundIsTheImageTopColor`가 알려준다).

# Hatcho Pixel Backgrounds — v2

픽셀 캐릭터를 돋보이게 하는 미니멀 배경 5종입니다.
앱 코드 및 테마 전환 기능은 이 패키지에 포함하지 않았습니다.

## Files

| Mode | File | Palette |
| --- | --- | --- |
| Dark | 01_Midnight_Navy.png | Smoky navy, dusty blue-violet, muted gold |
| Dark | 02_Cocoa_Night.png | Warm dark cocoa, mushroom taupe |
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

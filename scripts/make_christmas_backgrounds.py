#!/usr/bin/env python3
"""
크리스마스 월드 배경(원본 그림) → 앱 배경 에셋. 규칙은 images/backgrounds/README.md 와 같다.

  원본 → 화면 비율로 가운데 자르기(아이폰 9:16 / 아이패드 가로 4:3)
       → 실제 픽셀 격자로 줄이기(270×480 / 480×360) → 24색 이하·디더 없음
       → 앱 에셋(격자 그대로, 앱이 .interpolation(.none)로 키움) + 보관용 4배 PNG

밤 배경은 바닥(아래 30%)이 너무 밝으면 크림색 글자("Hatching progress" 등)가 안 읽힌다.
바닥 밝기가 FLOOR_MAX_LUM을 넘으면 바닥만 같은 색조로 어둡게 낮춘다(눈밭 → 달빛 눈밭).
기준은 기존 배경 중 가장 어두운 바닥 대비(Cocoa ≈ 3:1)와 같다 → AppThemeTests가 앱 번들 그림으로 다시 검사한다.

원본 바꾸기(예: 눈 덮인 밤 v3): 아래 BACKGROUNDS의 원본 파일을 덮어쓰고 다시 실행하면 된다.
  cp images/christmas-draft/backgrounds/xmas_bg_B_snowy_night_v3.png images/backgrounds/source/07_Snowy_Night_iPhone_raw.png
  python3 scripts/make_christmas_backgrounds.py
그다음 출력된 "top color"가 AppTheme.pageBackground와 다르면 그 값으로 고친다(테스트가 알려준다).

사용: uv run --with numpy --with pillow python scripts/make_christmas_backgrounds.py
"""
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BG = os.path.join(ROOT, "images", "backgrounds")
ASSETS = os.path.join(ROOT, "ios", "Eggtimer", "Assets.xcassets")

PHONE = dict(grid=(270, 480), native="Native_270x480", big="PNG_1080x1920", folder=BG)
# 아이패드 그림은 따로 생성돼 벽·하늘 색이 조금 다르다 → 아이폰 그림의 벽(위)·바닥(아래) 색에 맞춰 채널별로 보정한다.
# 아이패드를 돌리면 세로=아이폰 그림, 가로=이 그림이라 색이 같아야 안 튄다. 그래서 BACKGROUNDS에서 아이폰이 먼저 온다.
PAD = dict(grid=(480, 360), native="Native_480x360", big="PNG_1920x1440", folder=os.path.join(BG, "iPad"),
           match_phone=True)

# (보관 이름, 앱 에셋 이름, 원본 파일, 화면)
BACKGROUNDS = [
    ("06_Christmas_Eve", "BackgroundChristmasEve", "source/06_Christmas_Eve_iPhone_raw.png", PHONE),
    ("07_Snowy_Night", "BackgroundSnowyNight", "source/07_Snowy_Night_iPhone_raw.png", PHONE),
    ("06_Christmas_Eve", "BackgroundChristmasEveWide", "iPad/source/06_Christmas_Eve_iPad_raw.png", PAD),
    ("07_Snowy_Night", "BackgroundSnowyNightWide", "iPad/source/07_Snowy_Night_iPad_raw.png", PAD),
]

COLORS = 24            # README: 이미지당 최대 24색
EXPORT_SCALE = 4       # 보관용 확대(최근접)
FLOOR_FROM = 0.70      # 바닥 = 높이 70% 아래
TOP_TO = 0.30         # 위 = 타이머 자리(AppTheme.pageBackground)
FLOOR_MAX_LUM = 0.14   # 바닥 밝은 쪽(90번째 백분위) 상대휘도 상한. 크림 보조 글자(#D6C7B2) 대비 ≈ 3.2:1


def linear(c):
    c = np.asarray(c, dtype=np.float64) / 255.0
    return np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(lin):
    s = np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(lin, 1 / 2.4) - 0.055)
    return np.clip(np.round(s * 255), 0, 255)


def luminance(rgb):
    lin = linear(rgb)
    return 0.2126 * lin[..., 0] + 0.7152 * lin[..., 1] + 0.0722 * lin[..., 2]


def center_crop(im: Image.Image, aspect: float) -> Image.Image:
    w, h = im.size
    if w / h > aspect:
        cw = round(h * aspect)
        x = (w - cw) // 2
        return im.crop((x, 0, x + cw, h))
    ch = round(w / aspect)
    y = (h - ch) // 2
    return im.crop((0, y, w, y + ch))


def dim_floor(rgb: np.ndarray) -> tuple[np.ndarray, float]:
    """바닥이 FLOOR_MAX_LUM보다 밝으면 밝은 바닥(눈밭)이 시작되는 줄부터 아래만 선형광에서 같은 비율로
    어둡게(색조 유지). 고정 70% 줄부터 낮추면 그 위 나무·하늘까지 어두운 띠가 생긴다. 반환: (그림, 배율)."""
    h = rgb.shape[0]
    lum = luminance(rgb)
    p90 = np.percentile(lum[int(h * FLOOR_FROM):], 90)
    if p90 <= FLOOR_MAX_LUM:
        return rgb, 1.0
    row_median = np.median(lum, axis=1)
    start = next(r for r in range(int(h * 0.6), h) if row_median[r] > FLOOR_MAX_LUM)
    k = FLOOR_MAX_LUM / p90 * 0.97   # 양자화로 살짝 밝아져도 상한 아래에 남게
    out = rgb.copy()
    out[start:] = to_srgb(linear(rgb[start:]) * k)
    return out, k


def anchors(rgb: np.ndarray) -> np.ndarray:
    """위(벽·하늘)와 바닥의 중앙값 색. 생성 그림의 잔잡음에 흔들리지 않게 최빈값 대신 중앙값."""
    h = rgb.shape[0]
    top = np.median(rgb[: int(h * TOP_TO)].reshape(-1, 3), axis=0)
    floor = np.median(rgb[int(h * 0.80):].reshape(-1, 3), axis=0)   # 바닥선 근처(나무·벽난로 빛)는 뺀다
    return np.stack([top, floor])


def match_colors(rgb: np.ndarray, ref: np.ndarray) -> np.ndarray:
    """채널별 1차식(배율·더하기)으로 이 그림의 위·바닥 색을 ref(아이폰)의 위·바닥 색에 맞춘다."""
    own = anchors(rgb)
    out = rgb.copy()
    for c in range(3):
        span = own[1, c] - own[0, c]
        gain = (ref[1, c] - ref[0, c]) / span if abs(span) >= 16 else 1.0   # 두 색이 거의 같은 채널은 옮기기만
        out[..., c] = (rgb[..., c] - own[0, c]) * gain + ref[0, c]
    return np.clip(out, 0, 255)


PHONE_ANCHORS: dict[str, np.ndarray] = {}


def make(keep_name: str, asset: str, source: str, screen: dict) -> None:
    src = os.path.join(BG, source)
    if not os.path.exists(src):
        print(f"skip {asset}: 원본 없음 ({source})")
        return
    gw, gh = screen["grid"]
    im = center_crop(Image.open(src).convert("RGB"), gw / gh).resize((gw, gh), Image.BOX)
    rgb = np.asarray(im, dtype=np.float64)
    if screen.get("match_phone"):
        rgb = match_colors(rgb, PHONE_ANCHORS[keep_name])
    else:
        PHONE_ANCHORS[keep_name] = anchors(rgb)
    rgb, k = dim_floor(rgb)
    # MAXCOVERAGE+kmeans: 넓은 벽·하늘이 색을 독차지하지 않아 불꽃·장식·달 크레이터 색이 남는다(MEDIANCUT은 뭉갬)
    im = Image.fromarray(np.round(rgb).astype(np.uint8)).quantize(
        colors=COLORS, method=Image.Quantize.MAXCOVERAGE, kmeans=5, dither=Image.Dither.NONE)

    # 자체 검사: 격자 크기·색 수·바닥 밝기
    flat = np.asarray(im.convert("RGB"))
    assert im.size == (gw, gh), im.size
    n_colors = len(np.unique(flat.reshape(-1, 3), axis=0))
    assert n_colors <= COLORS, n_colors
    floor_p90 = np.percentile(luminance(flat[int(gh * FLOOR_FROM):]), 90)
    assert floor_p90 <= FLOOR_MAX_LUM, f"{asset} 바닥 밝기 {floor_p90:.3f}"

    # 타이머 자리(상단 30%)에서 가장 많은 색 = AppTheme.pageBackground
    top = flat[: int(gh * TOP_TO)].reshape(-1, 3)
    colors, counts = np.unique(top, axis=0, return_counts=True)
    r, g, b = colors[counts.argmax()]

    for sub, img in ((screen["native"], im), (screen["big"], im.resize((gw * EXPORT_SCALE, gh * EXPORT_SCALE), Image.NEAREST))):
        os.makedirs(os.path.join(screen["folder"], sub), exist_ok=True)
        img.save(os.path.join(screen["folder"], sub, f"{keep_name}.png"))
    write_imageset(asset, im)
    dim = f" · 바닥 ×{k:.2f}" if k < 1 else ""
    print(f"{asset}: {gw}×{gh}, {n_colors}색, top color 0x{r:02X}{g:02X}{b:02X}, 바닥 p90 {floor_p90:.3f}{dim}")


def write_imageset(name: str, im: Image.Image) -> None:
    d = os.path.join(ASSETS, f"{name}.imageset")
    os.makedirs(d, exist_ok=True)
    im.save(os.path.join(d, f"{name}.png"))
    contents = {
        "images": [
            {"filename": f"{name}.png", "idiom": "universal", "scale": "1x"},
            {"idiom": "universal", "scale": "2x"},
            {"idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
        "properties": {"compression-type": "lossless"},
    }
    with open(os.path.join(d, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    for row in BACKGROUNDS:
        make(*row)

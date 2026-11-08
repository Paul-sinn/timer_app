#!/usr/bin/env python3
"""
크리스마스 월드 그림 → 앱 에셋(Assets.xcassets).

1) 캐릭터 10종 × 3단계 × idle/action(60장)
   - 원본: images/final-character/{slug}/{slug}_stage{1-3}_{idle|action}.png (불투명 베이지 배경)
   - 배경 제거: 테두리에서 시작하는 flood fill(흰 털처럼 배경과 비슷한 안쪽 색은 보존).
     남은 조각 중 테두리에 닿은 것·아주 작은 점은 버린다(CLAUDE.md 2026-07-22 교훈).
   - 정렬: 단계마다 idle의 알파 bbox 아래-가운데를 기준점으로 잡고, action은 같은 이동량을 쓴다
     (codex가 idle을 고쳐 action을 만들었으니 원본 좌표 관계 = 의도한 점프·자세).
     6장을 캐릭터 공통 캔버스에 올려 크기가 같게 → CreatureArtTests가 강제.
   - 기존 캐릭터와 같이 캔버스 높이 660px로 맞춘다.
2) 선물상자 6단계(부화 그릇) → giftbox_stage{1-6}
   - 알 crack 에셋과 같은 590×566 캔버스·바닥선(y=548)·가운데(x=295.5).
   - 6장에 같은 변환 하나를 써서 단계 사이 상자가 튀지 않게 한다. 1단계 상자 높이 = 알 높이(400px).

사용: python3 scripts/make_christmas_assets.py
"""
import json
import os
import sys
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "ios", "Eggtimer", "Assets.xcassets")
CHAR_SRC = os.path.join(ROOT, "images", "final-character")
BOX_SRC = os.path.join(ROOT, "images", "eggs", "giftbox_opening_6_stage")

# 원본 폴더명 → 에셋 접두사(= CreatureSpecies.imageVariants)
CHARACTERS = {
    "red_nose_penguin": "RedNosePenguin",
    "santa_penguin": "SantaPenguin",
    "elf_penguin": "ElfPenguin",
    "gift_box_penguin": "GiftBoxPenguin",
    "snowman_slime": "SnowmanSlime",
    "little_ember": "LittleEmber",
    "arctic_fox": "ArcticFox",
    "gingerbread_chick": "GingerbreadChick",
    "snowy_owl": "SnowyOwl",
    "polar_bear": "PolarBear",
}

TOLERANCE = 40         # 배경으로 볼 색 거리
MIN_SPECK = 24         # 이보다 작은 조각(px)은 노이즈로 버림
# 고리(북극곰 3단계 아우라)처럼 테두리와 막힌 안쪽 배경: 배경색과 거의 같은(≤8) 덩어리가 이만큼 크면
# 그 자리도 배경으로 보고 같은 방식으로 지운다. 흰 털은 배경과 거리 30+라 씨앗이 되지 않는다.
ENCLOSED_TOL, ENCLOSED_MIN = 8, 200
CANVAS_H = 660         # 기존 캐릭터 에셋 높이
PAD_SIDE, PAD_TOP, PAD_BOTTOM = 24, 16, 14   # 기존 에셋 바닥 여백 14px

EGG_CANVAS = (590, 566)
EGG_BOTTOM, EGG_CENTER_X, EGG_HEIGHT = 548, 295.5, 400


def remove_background(src: Image.Image) -> Image.Image:
    im = src.convert("RGBA")
    w, h = im.size
    px = im.load()
    corners = [px[3, 3], px[w - 4, 3], px[3, h - 4], px[w - 4, h - 4]]
    br, bgc, bb = (sum(c[i] for c in corners) // 4 for i in range(3))
    tol2 = TOLERANCE * TOLERANCE

    def dist2(p):
        return (p[0] - br) ** 2 + (p[1] - bgc) ** 2 + (p[2] - bb) ** 2

    seen = bytearray(w * h)

    def flood(seeds):
        q = deque(seeds)
        while q:
            x, y = q.popleft()
            i = y * w + x
            if seen[i]:
                continue
            seen[i] = 1
            r, g, b, _ = px[x, y]
            if dist2((r, g, b)) > tol2:
                continue
            px[x, y] = (r, g, b, 0)
            if x > 0: q.append((x - 1, y))
            if x < w - 1: q.append((x + 1, y))
            if y > 0: q.append((x, y - 1))
            if y < h - 1: q.append((x, y + 1))

    flood([(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)])

    # 막힌 안쪽 배경 찾기: 배경색과 거의 같은 픽셀 덩어리 중 큰 것만 씨앗으로.
    tight2, mark = ENCLOSED_TOL * ENCLOSED_TOL, bytearray(w * h)
    for sy in range(h):
        for sx in range(w):
            i0 = sy * w + sx
            if mark[i0] or seen[i0] or dist2(px[sx, sy]) > tight2:
                continue
            comp, q = [], deque([(sx, sy)])
            mark[i0] = 1
            while q:
                x, y = q.popleft()
                comp.append((x, y))
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    j = ny * w + nx
                    if 0 <= nx < w and 0 <= ny < h and not mark[j] and not seen[j] and dist2(px[nx, ny]) <= tight2:
                        mark[j] = 1
                        q.append((nx, ny))
            if len(comp) >= ENCLOSED_MIN:
                flood(comp)

    # 남은 조각: 테두리에 닿거나 아주 작으면 버린다.
    label = bytearray(w * h)
    for sy in range(h):
        for sx in range(w):
            if label[sy * w + sx] or px[sx, sy][3] == 0:
                continue
            comp, touches = [], False
            q = deque([(sx, sy)])
            label[sy * w + sx] = 1
            while q:
                x, y = q.popleft()
                comp.append((x, y))
                if x in (0, w - 1) or y in (0, h - 1):
                    touches = True
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if 0 <= nx < w and 0 <= ny < h and not label[ny * w + nx] and px[nx, ny][3]:
                        label[ny * w + nx] = 1
                        q.append((nx, ny))
            if touches or len(comp) < MIN_SPECK:
                for x, y in comp:
                    r, g, b, _ = px[x, y]
                    px[x, y] = (r, g, b, 0)
    return im


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
    }
    with open(os.path.join(d, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
        f.write("\n")


def make_character(slug: str, prefix: str) -> None:
    frames = {}
    for s in (1, 2, 3):
        for pose in ("idle", "action"):
            path = os.path.join(CHAR_SRC, slug, f"{slug}_stage{s}_{pose}.png")
            frames[(s, pose)] = remove_background(Image.open(path))

    # 단계별 기준점 = idle bbox 아래-가운데. action도 같은 이동량.
    placed = {}
    for s in (1, 2, 3):
        ib = frames[(s, "idle")].getchannel("A").getbbox()
        ax, ay = (ib[0] + ib[2]) / 2, ib[3]
        for pose in ("idle", "action"):
            im = frames[(s, pose)]
            b = im.getchannel("A").getbbox()
            placed[(s, pose)] = (im.crop(b), b[0] - ax, b[1] - ay)   # 기준점 기준 좌상단

    half_w = max(max(abs(dx), abs(dx + c.width)) for c, dx, _ in placed.values())
    top = min(dy for _, _, dy in placed.values())
    bottom = max(dy + c.height for c, _, dy in placed.values())
    W = int(2 * half_w + 2 * PAD_SIDE)
    H = int(bottom - top + PAD_TOP + PAD_BOTTOM)
    scale = CANVAS_H / H
    out_w = round(W * scale)

    for (s, pose), (crop, dx, dy) in placed.items():
        canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        canvas.paste(crop, (round(W / 2 + dx), round(H - PAD_BOTTOM - bottom + dy)), crop)
        final = canvas.resize((out_w, CANVAS_H), Image.LANCZOS)
        write_imageset(f"{prefix}Stage{s}{pose.capitalize()}", final)
    print(f"{prefix}: canvas {out_w}x{CANVAS_H}")


def make_giftbox() -> None:
    frames = [remove_background(Image.open(os.path.join(BOX_SRC, f"giftbox_stage{i}.png")))
              for i in range(1, 7)]
    b1 = frames[0].getchannel("A").getbbox()
    scale = EGG_HEIGHT / (b1[3] - b1[1])
    ax, ay = (b1[0] + b1[2]) / 2, b1[3]
    for i, im in enumerate(frames, start=1):
        sw, sh = round(im.width * scale), round(im.height * scale)
        big = im.resize((sw, sh), Image.LANCZOS)
        canvas = Image.new("RGBA", EGG_CANVAS, (0, 0, 0, 0))
        canvas.paste(big, (round(EGG_CENTER_X - ax * scale), round(EGG_BOTTOM - ay * scale)), big)
        b = canvas.getchannel("A").getbbox()
        # 잘림 검사: 상자가 캔버스 가장자리에 닿으면 실패.
        assert b[0] > 0 and b[1] > 0 and b[2] < EGG_CANVAS[0] and b[3] < EGG_CANVAS[1], (i, b)
        write_imageset(f"giftbox_stage{i}", canvas)
    print(f"giftbox: scale {scale:.3f}, 6 stages on {EGG_CANVAS}")


if __name__ == "__main__":
    only = sys.argv[1:]
    for slug, prefix in CHARACTERS.items():
        if not only or slug in only:
            make_character(slug, prefix)
    if not only or "giftbox" in only:
        make_giftbox()

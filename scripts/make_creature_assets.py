#!/usr/bin/env python3
"""
캐릭터 PNG(크림색 단색 배경)를 투명 배경 + 여백 trim 한 imageset 에셋으로 변환한다.

- 테두리에서 BFS flood-fill 로 배경색과 가까운(연결된) 픽셀만 투명 처리한다.
  (단색 채우기와 달리 캐릭터 내부의 비슷한 색은 보존된다.)
- 투명 영역을 제외한 bounding box 로 trim 후 약간의 여백을 둔다.
- ios/Eggtimer/Assets.xcassets/<Name>.imageset/ 에 PNG + Contents.json 을 생성한다.
"""
import json
import os
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "images", "charactor")
ASSETS = os.path.join(ROOT, "ios", "Eggtimer", "Assets.xcassets")

# 원본 파일 → 에셋 이름 매핑
MAPPING = {
    # 빨간 토종닭 (Common) — 여러 표정 중 랜덤으로 출현
    "cutechick.png": "Chicken1",          # 기본 귀여움
    "angrychick.png": "ChickenAngry",     # 화남
    "annoyedchick.png": "ChickenAnnoyed",  # 시크
    "brochick.png": "ChickenBro",         # 근육
    "sleepychick.png": "ChickenSleepy",   # 졸림
    "smartchick.png": "ChickenSmart",     # 안경
    # 나머지 종
    "slime.png": "Slime",                          # 슬라임
    "dino.png": "Dino",                            # 아기 공룡
    "blackcat.png": "BlackCat",                    # 검은 고양이
    "goldchick.png": "GoldChick",                  # 황금 병아리
    "whitetiger.png": "WhiteTiger",                # 백호 (귀여움)
    "whitetiger_evolved.png": "WhiteTigerEvolved",  # 백호 (진화/간지)
    "phoenix.png": "Phoenix",                      # 피닉스 (귀여움)
    "phoenix_evolved.png": "PhoenixEvolved",       # 피닉스 (진화/간지)
}

TOLERANCE = 38      # 배경색으로 간주할 색 거리(제곱 비교)
PAD = 24            # trim 후 둘 여백(px)


def remove_background(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()

    # 네 모서리 평균을 배경색 기준으로 삼는다.
    samples = [px[2, 2], px[w - 3, 2], px[2, h - 3], px[w - 3, h - 3]]
    br = sum(s[0] for s in samples) // len(samples)
    bg = sum(s[1] for s in samples) // len(samples)
    bb = sum(s[2] for s in samples) // len(samples)
    tol2 = TOLERANCE * TOLERANCE

    def is_bg(r, g, b):
        dr, dg, db = r - br, g - bg, b - bb
        return dr * dr + dg * dg + db * db <= tol2

    visited = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            q.append((x, y))

    while q:
        x, y = q.popleft()
        idx = y * w + x
        if visited[idx]:
            continue
        visited[idx] = 1
        r, g, b, a = px[x, y]
        if not is_bg(r, g, b):
            continue
        px[x, y] = (r, g, b, 0)
        if x > 0:
            q.append((x - 1, y))
        if x < w - 1:
            q.append((x + 1, y))
        if y > 0:
            q.append((x, y - 1))
        if y < h - 1:
            q.append((x, y + 1))

    return im


def trim(im: Image.Image) -> Image.Image:
    bbox = im.getchannel("A").getbbox()
    if not bbox:
        return im
    l, t, r, b = bbox
    w, h = im.size
    l = max(0, l - PAD)
    t = max(0, t - PAD)
    r = min(w, r + PAD)
    b = min(h, b + PAD)
    return im.crop((l, t, r, b))


def contents_json(filename: str) -> str:
    return json.dumps(
        {
            "images": [
                {"filename": filename, "idiom": "universal", "scale": "1x"},
                {"idiom": "universal", "scale": "2x"},
                {"idiom": "universal", "scale": "3x"},
            ],
            "info": {"author": "xcode", "version": 1},
        },
        ensure_ascii=False,
        indent=2,
    )


def main():
    for src_name, asset in MAPPING.items():
        src_path = os.path.join(SRC, src_name)
        if not os.path.exists(src_path):
            raise SystemExit(f"원본 없음: {src_path}")
        im = Image.open(src_path)
        im = remove_background(im)
        im = trim(im)

        out_dir = os.path.join(ASSETS, f"{asset}.imageset")
        os.makedirs(out_dir, exist_ok=True)
        png_name = f"{asset}.png"
        im.save(os.path.join(out_dir, png_name))
        with open(os.path.join(out_dir, "Contents.json"), "w", encoding="utf-8") as f:
            f.write(contents_json(png_name))
        print(f"{asset:<18} {im.size}")


if __name__ == "__main__":
    main()

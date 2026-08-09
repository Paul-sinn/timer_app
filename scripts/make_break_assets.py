#!/usr/bin/env python3
"""
포모도로 휴식 아트(근접-블랙 배경 + 웜 비네트 + 반짝이)를 투명 배경 파생본으로 변환한다.

- 배경 제거: 테두리에서 BFS flood-fill 로 **휘도가 낮은(어두운) 연결 픽셀**만 투명화.
  → 어두운 bg/비네트/외곽선/바닥그림자는 제거되고, 밝은 피사체(병아리·컵·쿠션·화분·반짝이·연기·방울)는 보존.
  → 커피/화분 안쪽의 어두운 색은 밝은 외곽에 갇혀 테두리와 연결이 끊기므로 보존된다.
- 정렬: 장면(coffee/nap/stretch)의 두 프레임을 알파 bbox 로 crop 후 **공통 캔버스에 bottom-center 배치**.
  → 두 프레임의 캔버스 크기가 같아 프레임 전환에서 피사체가 세로로 튀지 않는다(낮잠 방울/스트레칭 팔은 위로만 변함).
- ios/Eggtimer/Assets.xcassets/<Name>.imageset/ 에 PNG + Contents.json(1x) 생성.
"""
import json
import os
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "images", "pomodorobreak")
ASSETS = os.path.join(ROOT, "ios", "Eggtimer", "Assets.xcassets")

# 장면 → [프레임1, 프레임2] (원본 파일명). 애니메이션 의미상 순서 중요.
SCENES = {
    # 커피: 두 프레임 연기 모양이 다름 → 느린 크로스페이드로 연기 피어오름.
    "BreakCoffee": ["졸린 병아리의 따뜻한 커피 휴식.png", "황금빛 머그잔과 쉬는 병아리.png"],
    # 낮잠: 1=작은 방울, 2=큰 방울 → 천천히 커졌다 작아짐(autoreverse).
    "BreakNap": ["황금 쿠션 위 병아리의 낮잠.png", "황금빛 잠든 병아리.png"],
    # 스트레칭: 1=웅크림, 2=쭉 펴기 → 웅크림→펴기→유지→웅크림.
    "BreakStretch": ["웅크린 병아리와 화분의 새싹.png", "새싹 옆 병아리의 상쾌한 스트레칭.png"],
}

LUMA_T = 80    # 이 휘도 미만이면 배경 후보(어두움). 비네트/외곽선 제거, 밝은 피사체 보존.
PAD = 20       # 공통 캔버스 여백(px)


def luma(r, g, b):
    return (r * 299 + g * 587 + b * 114) // 1000


def remove_background(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()

    visited = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.append((x, 0)); q.append((x, h - 1))
    for y in range(h):
        q.append((0, y)); q.append((w - 1, y))

    while q:
        x, y = q.popleft()
        idx = y * w + x
        if visited[idx]:
            continue
        visited[idx] = 1
        r, g, b, a = px[x, y]
        if luma(r, g, b) >= LUMA_T:   # 밝은 피사체 → 여기서 멈춤(보존)
            continue
        px[x, y] = (r, g, b, 0)       # 어두운 배경 → 투명
        if x > 0: q.append((x - 1, y))
        if x < w - 1: q.append((x + 1, y))
        if y > 0: q.append((x, y - 1))
        if y < h - 1: q.append((x, y + 1))

    return im


def place_bottom_center(cropped: Image.Image, cw: int, ch: int) -> Image.Image:
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    w, h = cropped.size
    x = (cw - w) // 2
    y = ch - PAD - h              # 바닥에서 PAD 만큼 띄우고 바닥 정렬
    canvas.alpha_composite(cropped, (x, y))
    return canvas


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
    for asset, files in SCENES.items():
        crops = []
        for name in files:
            src = os.path.join(SRC, name)
            if not os.path.exists(src):
                raise SystemExit(f"원본 없음: {src}")
            im = remove_background(Image.open(src))
            bbox = im.getchannel("A").getbbox()
            if not bbox:
                raise SystemExit(f"빈 알파(배경 제거 과함?): {name}")
            crops.append(im.crop(bbox))
        cw = max(c.width for c in crops) + 2 * PAD
        ch = max(c.height for c in crops) + 2 * PAD
        for i, c in enumerate(crops, start=1):
            out = place_bottom_center(c, cw, ch)
            out_dir = os.path.join(ASSETS, f"{asset}{i}.imageset")
            os.makedirs(out_dir, exist_ok=True)
            png = f"{asset}{i}.png"
            out.save(os.path.join(out_dir, png))
            with open(os.path.join(out_dir, "Contents.json"), "w", encoding="utf-8") as f:
                f.write(contents_json(png))
            print(f"{asset}{i:<2} canvas={out.size} crop={c.size}")


if __name__ == "__main__":
    main()

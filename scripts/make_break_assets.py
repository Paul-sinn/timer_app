#!/usr/bin/env python3
"""
포모도로 휴식 아트(근접-블랙 배경 + 웜 비네트 + 반짝이)를 투명 배경 파생본으로 변환한다.

- 배경 제거: 테두리에서 BFS flood-fill 로 **휘도가 낮은(어두운) 연결 픽셀**만 투명화.
  → 어두운 bg/비네트/바닥그림자는 제거되고, 밝은 피사체(병아리·컵·쿠션·화분·반짝이·연기·방울)는 보존.
  → 외곽선도 bg 와 같이 어두워 함께 지워지므로, 피사체를 OUTLINE px 팽창해 원본 외곽선을 되살린다
    (안 하면 파스텔 테마에서 선이 사라져 몸통이 배경에 녹는다).
  → 팽창 후 테두리와 끊긴 구멍은 평균이 밝으면(커피) 채우고, 배경처럼 어두우면(손잡이 안쪽) 비운다.
  → 밝은 테두리에 갇혀 처음부터 남은 두꺼운 배경(손잡이 안쪽)도 뚫는다.
- 정렬: 장면(coffee/nap/stretch)의 두 프레임을 알파 bbox 로 crop 후 **공통 캔버스에 bottom-center 배치**.
  → 두 프레임의 캔버스 크기가 같아 프레임 전환에서 피사체가 세로로 튀지 않는다(낮잠 방울/스트레칭 팔은 위로만 변함).
- ios/Eggtimer/Assets.xcassets/<Name>.imageset/ 에 PNG + Contents.json(1x) 생성.
"""
import json
import os
from collections import deque

from PIL import Image, ImageFilter

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
OUTLINE = 6    # 되살릴 외곽선 두께(px). 원본 도트 1칸 ≈ 8px.
HOLE_LUMA = 30 # 갇힌 구멍 평균 휘도. 이 이상=내용물(커피 ~50)로 채움, 미만=배경(손잡이 안쪽 ~15)으로 비움.


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


def restore_outline(im: Image.Image) -> Image.Image:
    """remove_background 결과의 피사체를 OUTLINE px 팽창(원본 픽셀 복원) + 갇힌 밝은 구멍 채움."""
    w, h = im.size
    a = im.getchannel("A").filter(ImageFilter.MaxFilter(2 * OUTLINE + 1)).load()
    px = im.load()

    # 테두리와 이어진 투명 = 진짜 배경(0 유지). 나머지 투명은 구멍.
    outside = bytearray(w * h)
    q = deque([(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)])
    while q:
        x, y = q.popleft()
        if not (0 <= x < w and 0 <= y < h) or outside[y * w + x] or a[x, y]:
            continue
        outside[y * w + x] = 1
        q.extend(((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))

    seen = bytearray(w * h)
    for sy in range(h):
        for sx in range(w):
            if a[sx, sy] or outside[sy * w + sx] or seen[sy * w + sx]:
                continue
            hole, q = [], deque([(sx, sy)])
            while q:
                x, y = q.popleft()
                if not (0 <= x < w and 0 <= y < h) or seen[y * w + x] or a[x, y]:
                    continue
                seen[y * w + x] = 1
                hole.append((x, y))
                q.extend(((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))
            if sum(luma(*px[p][:3]) for p in hole) / len(hole) >= HOLE_LUMA:
                for p in hole:
                    a[p] = 255

    # 밝은 테두리에 갇혀 처음부터 안 지워진 배경(머그 손잡이 안쪽)을 뚫는다.
    # OUTLINE 보다 두꺼운 아주 어두운 영역만 → 눈·선은 얇아서 살고, 구멍 둘레엔 외곽선이 남는다.
    core = im.convert("L").point(lambda v: 255 if v < HOLE_LUMA else 0).filter(ImageFilter.MinFilter(2 * OUTLINE + 1)).load()
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            px[x, y] = (r, g, b, 0 if core[x, y] else a[x, y])
    return im


def edge_luma(im: Image.Image) -> float:
    """불투명 픽셀 중 투명과 맞닿은 가장자리의 평균 휘도. 외곽선이 살아 있으면 어둡다."""
    w, h = im.size
    px = im.load()
    edge = [
        luma(*px[x, y][:3])
        for y in range(1, h - 1) for x in range(1, w - 1)
        if px[x, y][3] and not all(px[n][3] for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))
    ]
    return sum(edge) / len(edge)


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
            im = restore_outline(remove_background(Image.open(src)))
            bbox = im.getchannel("A").getbbox()
            if not bbox:
                raise SystemExit(f"빈 알파(배경 제거 과함?): {name}")
            # 가장자리가 밝으면 외곽선이 지워진 것 → 파스텔 테마에서 몸통이 배경에 녹는다.
            if (e := edge_luma(im)) >= LUMA_T:
                raise SystemExit(f"외곽선 소실(가장자리 휘도 {e:.0f}): {name}")
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

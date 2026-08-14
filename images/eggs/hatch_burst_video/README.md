# 부화 버스트 영상 (HEVC + 알파)

앱에서 재생하는 파일: `ios/Eggtimer/Resources/HatchBurst.mov`
이 폴더의 `source_hatcho_prebirth_smooth.mp4`가 그 원본이다. **원본은 손대지 않는다.**

기존 PNG 7프레임(`../hatch_charge_burst_6_frame_assets/`)은 폭발 구간이 초당 8프레임이라 끊겼다.
같은 아트를 60fps 168프레임으로 담은 영상으로 교체했고, PNG 시퀀스는 폴백으로 남겨뒀다.

## 왜 GIF가 아닌가

앱 배경(테마마다 다름) 위에 합성해야 하니 **투명도가 필수**다.
iOS가 네이티브로 재생하는 투명 동영상 포맷은 HEVC 알파(`hvc1`)뿐이라 그걸 쓴다.

## 원본 규격

| 항목 | 값 |
|---|---|
| 해상도 | 942 × 1672 (기존 PNG 원본 941×1672과 같은 좌표계) |
| 프레임 | 60fps · 168프레임 · 2.8초 |
| 코덱 | h264 yuv420p, **알파 없음** |
| 배경 | 단색 `#25232A` (테두리 전체가 정확히 1색 → 키잉 깔끔) |
| 오디오 | 없음 (유저 음악을 안 끊는다) |

## 변환 레시피

```bash
ffmpeg -i source_hatcho_prebirth_smooth.mp4 \
  -vf "crop=606:566:167:672,format=rgba,colorkey=0x25232A:0.10:0.0,premultiply=inplace=1,format=bgra" \
  -c:v hevc_videotoolbox -alpha_quality 0.6 -q:v 45 -tag:v hvc1 -allow_sw 1 -an \
  -y HatchBurst.mov
```

각 단계 이유:

- **`crop=606:566:167:672`** — 원본 캔버스 그대로 쓰면 알이 3배 작게 나온다(1672px 캔버스 기준으로 축소되니까).
  기존 crack PNG가 941×1672 원본을 `x=175, y=672, 590×566`으로 크롭해 쓰는데, 영상도 같은 좌표계라 같은 크롭을 쓴다.
  다만 168프레임 전체의 알파 bbox를 재보니 파편이 `x=170`까지 나가 왼쪽 5px이 잘렸다 → 좌우로 8px씩 대칭 확장해 `606` 폭.
  **세로 566은 crack PNG와 반드시 같아야 한다** — 같은 `.frame(height:)`에서 알 크기·바닥선이 일치해야 전환 때 안 튄다.
- **`colorkey=0x25232A:0.10:0.0`** — 단색 배경을 알파로. blend=0이라 경계가 이진(픽셀아트에 맞음).
- **`premultiply=inplace=1`** — ⚠️ **빠뜨리면 안 된다.** `colorkey`는 알파만 0으로 만들고 RGB에 원본 배경색을 남긴다.
  VideoToolbox는 결과를 `PremultipliedAlpha`로 태깅하므로 CoreAnimation이 `src + (1-a)*dst`로 합성 →
  투명 영역마다 `#25232A`가 **더해져** 앱 배경 위에 회색 판이 생긴다.
  (실측: 앱 배경 `(23,19,16)` + `(37,35,42)` = 화면에 찍힌 `(59,53,60)`.)
  `EggtimerTests/HatchBurstAssetTests.transparentPixelsArePremultiplied()`가 이 회귀를 막는다.
- **`-alpha_quality 0.6`** — 용량을 정하는 실질적 손잡이. `-q:v`는 60fps에서 1.6MB 밑으로 안 내려가지만
  alpha_quality는 0.9→1.3MB, 0.35→0.9MB로 크게 움직인다. 0.6이 경계 프린지(624px)와 용량(1.3MB)의 절충점.
- **`-tag:v hvc1`** — Apple 플레이어가 인식하는 태그. `hev1`이면 재생 안 될 수 있다.

## 검증

```bash
# 알파가 살아있는지(가장 잘 깨지는 부분)
ffprobe -v error -show_entries stream=pix_fmt HatchBurst.mov   # yuv420p로 보인다 — 알파는 보조 레이어라 여기 안 뜬다
```

ffprobe로는 알파 유무를 알 수 없다. **유닛 테스트로 판정한다**:

```bash
cd ios && xcodebuild test -project Eggtimer.xcodeproj -scheme Eggtimer \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:EggtimerTests/HatchBurstAssetTests
```

번들 포함 · 알파 채널 · premultiply · 길이 2.8초 · 캔버스 606×566을 전부 검사한다.

화면 합성은 DEBUG 훅으로 눈으로 본다(반복 재생):

```bash
SIMCTL_CHILD_HATCH_BURST=1 xcrun simctl launch <device> com.paulsin.hatchly
```

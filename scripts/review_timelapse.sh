#!/usr/bin/env bash
#
# App Store 심사용 화면녹화 타임랩스 편집.
#
# 25분 집중 세션을 실시간으로 다 보여줄 수 없으니 "지루한 가운데 구간"만 빨리감고
# 앞뒤(세션 시작 · 부화 순간)는 등속으로 남긴다. 빨리감기 구간에는 심사자가 오해하지
# 않도록 "FAST-FORWARDED xN" 자막을 태운다.
#
# 사용법:
#   ./review_timelapse.sh <입력영상> <빨리감기_시작> <빨리감기_끝> [배속] [출력파일]
#
# 예: 1분30초부터 24분00초까지를 30배속으로
#   ./review_timelapse.sh rec.mov 00:01:30 00:24:00 30 hatcho_review.mp4
#
# 시간은 HH:MM:SS 또는 초(숫자) 둘 다 된다.
# 오디오는 버린다(앱에 사운드가 없어 무음 트랙이다).

set -euo pipefail

IN="${1:?입력 영상 경로가 필요하다}"
FF_START="${2:?빨리감기 시작 시각 (예: 00:01:30)}"
FF_END="${3:?빨리감기 끝 시각 (예: 00:24:00)}"
SPEED="${4:-30}"
OUT="${5:-review_edited.mp4}"
# 출력 가로폭. 화면녹화 원본(1206px)은 심사 제출에 과하다 — 줄이면 용량·인코딩 시간이 크게 준다.
OUT_WIDTH="${OUT_WIDTH:-720}"

[[ -f "$IN" ]] || { echo "입력 파일이 없다: $IN" >&2; exit 1; }

# HH:MM:SS / MM:SS / 초 → 초(소수 허용).
# 필터그래프 안에서는 콜론이 옵션 구분자라 시:분:초를 그대로 쓸 수 없다. 반드시 초로 바꾼다.
to_seconds() {
  local t="$1"
  case "$t" in
    *:*:*) IFS=: read -r h m s <<< "$t"; echo "$h*3600 + $m*60 + $s" | bc -l ;;
    *:*)   IFS=: read -r m s <<< "$t";   echo "$m*60 + $s" | bc -l ;;
    *)     echo "$t" ;;
  esac
}

FF_START_S=$(to_seconds "$FF_START")
FF_END_S=$(to_seconds "$FF_END")

awk -v a="$FF_START_S" -v b="$FF_END_S" 'BEGIN { if (a+0 >= b+0) exit 1 }' \
  || { echo "빨리감기 끝($FF_END)이 시작($FF_START)보다 앞이다." >&2; exit 1; }


# 자막: 배속을 그대로 표기해 "속임수"로 보이지 않게 한다.
LABEL="FAST-FORWARDED x${SPEED}"

# 폰트는 fontconfig 이름으로 준다(경로에 공백이 있으면 필터 파싱이 깨진다).
DRAW="drawtext=font=Arial:text='${LABEL}':fontcolor=white:fontsize=h/32"
DRAW+=":box=1:boxcolor=black@0.75:boxborderw=h/90"
DRAW+=":x=(w-text_w)/2:y=h-text_h-(h/12)"

ffmpeg -hide_banner -i "$IN" -filter_complex "
  [0:v]trim=start=0:end=${FF_START_S},setpts=PTS-STARTPTS[head];
  [0:v]trim=start=${FF_START_S}:end=${FF_END_S},setpts=(PTS-STARTPTS)/${SPEED},${DRAW}[mid];
  [0:v]trim=start=${FF_END_S},setpts=PTS-STARTPTS[tail];
  [head][mid][tail]concat=n=3:v=1:a=0,scale=${OUT_WIDTH}:-2[v]
" -map "[v]" -an \
  -c:v libx264 -preset medium -crf 23 -pix_fmt yuv420p -movflags +faststart \
  -y "$OUT"

echo
echo "완료: $OUT"
ffprobe -v error -show_entries format=duration,size -of default=noprint_wrappers=1 "$OUT"

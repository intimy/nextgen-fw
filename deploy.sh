#!/usr/bin/env bash
# 다음세대 가정예배 플랫폼 — GitHub Pages 주간 갱신 스크립트 (멱등·안전)
# 소스(룸 산출 사이트 폴더)의 최신 HTML을 이 배포 레포로 동기화 → commit → push.
# 사용: ./deploy.sh        (오늘 날짜로 자동 커밋)
#      ./deploy.sh "메모"  (커밋 메시지 뒤에 메모 덧붙임)
set -euo pipefail

# --- 소스 경로(룸 사이트 빌드 결과). 필요시 환경변수로 덮어쓰기 가능 ---
SRC="${NEXTGEN_SITE_SRC:-$HOME/.intimyai/rooms/nextgen_site}"
DEST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -d "$SRC" ]; then
  echo "[ERROR] 소스 경로 없음: $SRC" >&2
  echo "        NEXTGEN_SITE_SRC=<경로> ./deploy.sh 로 지정하세요." >&2
  exit 1
fi

echo "[1/4] 소스 → 배포 레포 동기화 (HTML만, 삭제분도 반영)"
# .git / .nojekyll / deploy.sh / README.md 는 보존, html 트리만 거울복사
rsync -a --delete \
  --exclude='.git/' --include='*/' --include='*.html' --exclude='*' \
  "$SRC/" "$DEST/"

# Jekyll 우회 마커 보장
touch "$DEST/.nojekyll"

echo "[2/4] 변경 확인"
cd "$DEST"
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
  echo "변경 없음 — 커밋/푸시 건너뜀."
  exit 0
fi

echo "[3/4] 커밋"
# add 범위 한정(글로벌 규범: git add -A 금지 — 2026-07-16 .DS_Store 유입 사고로 교정)
git add -A -- '*.html' 부서 허브 .nojekyll .gitignore 2>/dev/null || git add -- '*.html'
MSG="update $(date +%Y-%m-%d)"
if [ "${1:-}" != "" ]; then MSG="$MSG — $1"; fi
git -c core.editor=true commit -m "$MSG"

echo "[4/4] 푸시"
if git remote get-url origin >/dev/null 2>&1; then
  git push origin HEAD
  echo "완료. 1~2분 후 GitHub Pages 반영."
else
  echo "[주의] origin 리모트가 아직 없습니다. README의 최초 1회 설정을 먼저 하세요."
  echo "       커밋은 로컬에 저장됨. 리모트 연결 후 'git push -u origin main' 하면 됩니다."
fi

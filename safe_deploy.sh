#!/usr/bin/env bash
# safe_deploy.sh — 다음세대 사이트 '민감정보 게이트 + 배포' 래퍼 (2026-07-03)
# 주간 갱신분 자동 반영 훅. blind push 금지 — 스캔 통과 시에만 deploy.sh 실행.
# 미래 주차에 실명(탈북 간증 게스트 등)이 재유입돼도 자동 발행되지 않게 차단.
set -uo pipefail
SRC="${NEXTGEN_SITE_SRC:-$HOME/.intimyai/rooms/nextgen_site}"
DEST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAG="$HOME/.intimyai/NEXTGEN_DEPLOY_BLOCKED"
rm -f "$FLAG"
echo "[게이트] 민감정보 스캔: $SRC"
hits=0
scan() { # $1=설명 $2=grep패턴(-E)
  local m; m=$(grep -rnoE "$2" "$SRC" --include='*.html' 2>/dev/null | grep -vE '2026|1080|마리로|성경책을 들고' | head -8)
  if [ -n "$m" ]; then echo "  ⚠️ [$1] 발견:"; echo "$m" | sed 's/^/       /'; hits=$((hits+1)); fi
}
# 1) 기존 익명화 대상 재유입 가드
scan "기존실명 재유입" '최승혁|현비파|이은성'
# 2) 명명된 사역자(게스트 실명 후보) — '한 …님' 익명형은 제외
nm=$(grep -rnoE '[가-힣]{2,4}(전도사님|선교사님)' "$SRC" --include='*.html' 2>/dev/null | grep -vE '한 (탈북민 )?(전도사|선교사)님|우리 전도사님' | head -8)
[ -n "$nm" ] && { echo "  ⚠️ [명명된 전도사/선교사] 검토 필요:"; echo "$nm" | sed 's/^/       /'; hits=$((hits+1)); }
mp=$(grep -rnoE '[가-힣]{2,4}목사님' "$SRC" --include='*.html' 2>/dev/null | grep -vE '한 목사님|담임목사님|부목사님|우리 목사님|강사 목사님' | head -8)
[ -n "$mp" ] && { echo "  ⚠️ [명명된 목사] 검토 필요:"; echo "$mp" | sed 's/^/       /'; hits=$((hits+1)); }
# 3) 연락처·주소·학교
scan "전화번호" '01[0-9][-. ][0-9]{3,4}[-. ][0-9]{4}'
scan "이메일" '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.(com|net|kr|org)'
scan "학교실명" '[가-힣]{2,6}(초등학교|중학교|고등학교)'
# 4) 탈북 식별 디테일
scan "탈북 식별디테일" '총살|인신매매|두만강|압록강'

if [ "$hits" -gt 0 ]; then
  echo "🔴 게이트 실패 — $hits 항목. 배포 중단(push 안 함). 익명화 후 재실행하세요."
  touch "$FLAG"
  # master 알림(escalate 있으면)
  ESC="$HOME/tools/company/escalate.sh"
  [ -x "$ESC" ] && "$ESC" "📤 발행연동" blocker urgent "다음세대 자동배포 게이트 차단 — 민감정보 $hits건 재검출" "safe_deploy 스캔이 실명/연락처/식별디테일 감지→push 중단. 익명화 필요." D >/dev/null 2>&1
  exit 1
fi
echo "[게이트] ✅ 통과 — 배포 진행"
exec "$DEST/deploy.sh" "${1:-주간 자동 갱신}"

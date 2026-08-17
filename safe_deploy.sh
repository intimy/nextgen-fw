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

# fail-closed 전제 — 스캔 대상이 없으면 '깨끗함'이 아니라 '확인 못 함'이다.
# 이게 없으면 SRC 경로가 틀렸을 때 검출 0건으로 통과해 그대로 push된다.
if [ ! -d "$SRC" ]; then
  echo "🔴 게이트 실패 — 스캔 대상 없음: $SRC. 배포 중단."
  touch "$FLAG"
  printf '{"ts":"%s","src":"nextgen_deploy","msg":"%s"}\n' \
    "$(date +%Y-%m-%dT%H:%M:%S%z)" "자동배포 게이트 차단 — 스캔 대상 디렉터리 부재($SRC), push 중단." \
    >> "$HOME/.intimyai/_escalations.jsonl"
  exit 1
fi
if [ "$(find "$SRC" -name '*.html' -type f 2>/dev/null | head -1 | wc -l | tr -d ' ')" != "1" ]; then
  echo "🔴 게이트 실패 — 스캔할 html이 0개다: $SRC. 배포 중단."
  touch "$FLAG"
  printf '{"ts":"%s","src":"nextgen_deploy","msg":"%s"}\n' \
    "$(date +%Y-%m-%dT%H:%M:%S%z)" "자동배포 게이트 차단 — 스캔 대상 html 0개($SRC), push 중단." \
    >> "$HOME/.intimyai/_escalations.jsonl"
  exit 1
fi
scan() { # $1=설명 $2=grep패턴(-E)
  local m; m=$(grep -rnoE "$2" "$SRC" --include='*.html' 2>/dev/null | grep -vE '2026|1080|마리로|성경책을 들고' | head -8)
  if [ -n "$m" ]; then echo "  ⚠️ [$1] 발견:"; echo "$m" | sed 's/^/       /'; hits=$((hits+1)); fi
}
# 1) 기존 익명화 대상 재유입 가드
scan "기존실명 재유입" '최승혁|현비파|이은성'
# 2) 명명된 사역자(실명+직함) — '님'이 없어도, 어떤 직함이어도 잡는다.
#    2026-08-17 실사고: 구 패턴은 '님'이 필수라 '김세현 목사'(님 없음)를 4주간 놓쳤고,
#    '강도사'·'학생' 직함은 패턴에 아예 없어 미성년 실명이 그대로 발행됐다.
#    제외 목록은 '이름이 아닌 말 + 직함'만이다(담임목사·고등학생 등).
NAMED_TITLE='[가-힣]{2,4} ?(목사|전도사|강도사|선교사|집사|권사|장로|학생|청년|형제|자매)님?'
NOT_A_NAME='(담임|부담임|우리|저희|강사|협동|원로|은퇴|선임|초청|영아|유아|유치|유년|초등|소년|중등|고등|청년|장년|대학) ?(목사|전도사|강도사|선교사|집사|권사|장로|학생|청년|형제|자매)님?|한 (탈북민 )?(전도사|선교사|목사|학생)님?|부목사님'
nm=$(grep -rnoE "$NAMED_TITLE" "$SRC" --include='*.html' 2>/dev/null | grep -vE "$NOT_A_NAME" | head -8)
[ -n "$nm" ] && { echo "  ⚠️ [명명된 사역자·학생 실명] 검토 필요:"; echo "$nm" | sed 's/^/       /'; hits=$((hits+1)); }
# 3) 연락처·주소·학교
scan "전화번호" '01[0-9][-. ][0-9]{3,4}[-. ][0-9]{4}'
scan "이메일" '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.(com|net|kr|org)'
scan "학교실명" '[가-힣]{2,6}(초등학교|중학교|고등학교)'
# 4) 탈북 식별 디테일
scan "탈북 식별디테일" '총살|인신매매|두만강|압록강'

# 오류 착지 단일 지점(아침 브리핑이 pending 읽음) — 구 escalate.sh는 2026-07-16 대청소로 실종, jsonl 직결로 교체
escalate_jsonl() { # $1=msg
  printf '{"ts":"%s","src":"nextgen_deploy","msg":"%s"}\n' \
    "$(date +%Y-%m-%dT%H:%M:%S%z)" "$1" >> "$HOME/.intimyai/_escalations.jsonl"
}

if [ "$hits" -gt 0 ]; then
  echo "🔴 게이트 실패 — $hits 항목. 배포 중단(push 안 함). 익명화 후 재실행하세요."
  touch "$FLAG"
  escalate_jsonl "자동배포 게이트 차단 — 민감정보 ${hits}건 검출, push 중단. 익명화 후 재실행 필요."
  exit 1
fi
echo "[게이트] ✅ 통과 — 배포 진행"
rc=0
"$DEST/deploy.sh" "${1:-주간 자동 갱신}" || rc=$?
if [ "$rc" -ne 0 ]; then
  escalate_jsonl "배포 실패(rc=${rc}) — 게이트는 통과했으나 rsync/commit/push 단계 오류. nextgen_deploy.log 확인 필요."
  exit "$rc"
fi

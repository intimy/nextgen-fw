#!/usr/bin/env bash
# 다음세대 가정예배 플랫폼 — GitHub Pages 주간 갱신 스크립트 (멱등·안전)
# 소스(룸 산출 사이트 폴더)의 최신 HTML을 이 배포 레포로 동기화 → commit → push.
# 사용: ./deploy.sh        (오늘 날짜로 자동 커밋)
#      ./deploy.sh "메모"  (커밋 메시지 뒤에 메모 덧붙임)
#
# [AP-20260826-08 수리 · 2026-08-26] 근거 = 08-26 18:00 rc=1(변경 판정은 트리 전체인데 커밋 add는 HTML 범위뿐이라
#   비HTML만 더러우면 0개 스테이징 → "no changes added to commit"으로 사망) + 08-22 14:57 rc=128(동시 실행 index.lock 추정).
#   ① 판정과 커밋이 같은 pathspec(PATHSPEC) 하나를 쓴다  ② lockf 자기 재실행 잠금으로 동시 실행을 직렬화한다.
# [이 수리가 못 잡는 것] 커밋 범위 밖(README·스크립트 등) dirty는 경고만 하고 치우지 않는다(사람 몫).
#   잠금은 이 머신 안에서만 유효하고, rc=141(SIGPIPE)·rc=127(command not found) 계열 실패는 이 수리 밖이다.
set -euo pipefail

# --- 실행 잠금: 동시 실행을 막는 게 아니라 직렬화한다(멱등이라 2번째는 "변경 없음"으로 끝난다) ---
# 잠금 파일은 레포 밖에 둔다(공개 레포이자 rsync --delete 대상).
# 기본 120초를 기다려도 못 잡으면 lockf가 rc!=0으로 죽고 escalate_wrap 경보가 뜬다 — 그건 진짜 이상 신호다.
LOCK="${NEXTGEN_DEPLOY_LOCK:-$HOME/.intimyai/locks/nextgen_deploy.lock}"
if [ -z "${NEXTGEN_DEPLOY_LOCKED:-}" ]; then
  mkdir -p "$(dirname "$LOCK")"
  export NEXTGEN_DEPLOY_LOCKED=1
  exec /usr/bin/lockf -t "${NEXTGEN_DEPLOY_LOCK_WAIT:-120}" "$LOCK" /usr/bin/env bash "$0" "$@"
fi

# --- 소스 경로(룸 사이트 빌드 결과). 필요시 환경변수로 덮어쓰기 가능 ---
SRC="${NEXTGEN_SITE_SRC:-$HOME/.intimyai/rooms/nextgen_site}"
DEST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- 커밋 범위 = 변경 판정 범위. 여기 한 곳에서만 정의한다(둘이 어긋나면 08-26 18:00 rc=1이 재발한다) ---
PATHSPEC=( '*.html' '부서' '허브' '.nojekyll' '.gitignore' )
# 위 범위의 여집합(경고 전용). pathspec exclude magic — 없는 디렉터리가 섞여도 diff/status는 조용히 rc=0.
PATHSPEC_OUT=( '.' )
for _p in "${PATHSPEC[@]}"; do PATHSPEC_OUT+=( ":(exclude)$_p" ); done

if [ ! -d "$SRC" ]; then
  echo "[ERROR] 소스 경로 없음: $SRC" >&2
  echo "        NEXTGEN_SITE_SRC=<경로> ./deploy.sh 로 지정하세요." >&2
  exit 1
fi

echo "[1/4] 소스 → 배포 레포 동기화 (HTML만, 삭제분도 반영)"
# .git / .nojekyll / deploy.sh / README.md 는 보존, html 트리만 거울복사
rsync -a --delete \
  --exclude='.git/' --exclude='/_internal/' --include='*/' --include='*.html' --exclude='*' \
  "$SRC/" "$DEST/"

# Jekyll 우회 마커 보장
touch "$DEST/.nojekyll"

echo "[2/4] 변경 확인 (커밋 범위와 동일)"
cd "$DEST"

# 커밋 범위 밖 dirty를 조용히 넘기지 않는다 — 경고만 하고 치우지는 않는다(파괴 금지).
warn_outside() {
  local out
  out="$(git status --porcelain -- "${PATHSPEC_OUT[@]}" 2>/dev/null)" || out=""
  [ -n "$out" ] || return 0
  echo "[주의] 커밋 범위 밖 변경 $(printf '%s\n' "$out" | wc -l | tr -d ' ')건 — 커밋하지 않고 그대로 둡니다(사람이 확인하세요):"
  printf '%s\n' "$out" | head -10 | sed 's/^/       /'
}

changed=0
git diff --quiet -- "${PATHSPEC[@]}" || changed=1                                  # 수정·삭제(rsync --delete 반영분)
git diff --cached --quiet -- "${PATHSPEC[@]}" || changed=1                          # 이미 스테이징된 분
[ -z "$(git ls-files --others --exclude-standard -- "${PATHSPEC[@]}")" ] || changed=1  # 신규(untracked)

if [ "$changed" -eq 0 ]; then
  echo "변경 없음 — 커밋/푸시 건너뜀."
  warn_outside
  exit 0
fi

echo "[3/4] 커밋"
# add 범위 한정(글로벌 규범: git add -A 금지 — 2026-07-16 .DS_Store 유입 사고로 교정)
# 부서/허브가 아직 없는 클론에서는 git add가 pathspec 오류로 죽으므로 단계적으로 폴백한다.
git add -A -- "${PATHSPEC[@]}" 2>/dev/null \
  || git add -A -- '*.html' .nojekyll 2>/dev/null \
  || git add -A -- '*.html'

# 2중 안전: 스테이징이 빈 채로 commit을 부르면 rc=1로 죽는다(08-26 18:00 사고의 마지막 한 걸음).
if git diff --cached --quiet; then
  echo "변경 없음(커밋 범위 밖 변경만 있음) — 커밋/푸시 건너뜀."
  warn_outside
  exit 0
fi

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

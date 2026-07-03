# 다음세대 주중 가정예배 · 큐티 플랫폼 (GitHub Pages 배포)

수영로교회 다음세대 8부서 주중 가정예배지 + 매일 큐티 정적 HTML 사이트.
임시 cloudflared 터널을 대체하는 **영구 무료 배포**(GitHub Pages).

- 진입점: `index.html` (허브)
- 소스(룸 산출): `~/.intimyai/rooms/nextgen_site/` — 이 레포는 그 **복사본**(원본 보존)
- 매주 갱신: `./deploy.sh`
- 검색 비노출: 모든 HTML `<head>`에 `<meta name="robots" content="noindex,nofollow">` (링크 아는 사람만)
- Jekyll 우회: `.nojekyll` (한글/언더스코어 파일 처리 안전)

레포명 제안: **`nextgen-fw`** (nextgen family worship — 노출 적은 무난한 슬러그)

---

## ⓐ 박사님이 1회만 (인증 — 게이트)

터미널에 **딱 한 줄**:

```bash
gh auth login
```

> 안내: GitHub.com → HTTPS → 브라우저 로그인. (또는 PAT: `repo` 권한 토큰으로 로그인)
> `gh` 없으면 먼저 `brew install gh`.
> 인증 완료 확인: `gh auth status`

이게 끝입니다. 아래는 master가 처리합니다.

---

## ⓑ master가 (인증 후) 칠 명령 시퀀스

```bash
cd ~/Projects/nextgen-worship-site

# 1) 레포 생성 + origin 연결 + 최초 푸시 (public — 무료 Pages 조건)
gh repo create nextgen-fw --public --source . --remote origin --push

# 2) GitHub Pages 활성 (main 브랜치 루트)
gh api -X POST "repos/{owner}/nextgen-fw/pages" \
  -f "source[branch]=main" -f "source[path]=/" 2>/dev/null \
  || echo "Pages API 실패 시: Settings > Pages > Source=main /(root) 수동 설정"

# 3) 배포 URL 확인 (반영 1~2분)
gh api "repos/{owner}/nextgen-fw/pages" --jq .html_url 2>/dev/null
```

> `{owner}`는 `gh` 인증 계정으로 자동 치환됨. 안 되면 실제 사용자명으로 교체.

---

## ⓒ 결과 URL 형식

```
https://<사용자명>.github.io/nextgen-fw/
```

이 링크를 부서/가정에 공유. 진입점 `index.html`이 자동으로 열림.

---

## ⓓ 매주 갱신 (master, 인증 후 상시)

룸에서 새 주차를 렌더해 `~/.intimyai/rooms/nextgen_site/`가 갱신되면:

```bash
cd ~/Projects/nextgen-worship-site
./deploy.sh
```

소스의 최신 HTML을 거울복사(삭제분 포함) → 커밋 → 푸시. 멱등(변경 없으면 건너뜀).
소스 경로가 다르면: `NEXTGEN_SITE_SRC=<경로> ./deploy.sh`

---

## 한계·주의

- **무료 GitHub Pages = public 레포**가 조건. 콘텐츠가 GitHub에서 *검색 노출은 안 되게* `noindex`를 넣었지만, **링크/URL을 아는 사람은 접근 가능**(진정한 비공개 아님).
- 진짜 비공개(인증 필요 사이트)는 **GitHub Pro/Team** 유료 + private repo Pages가 필요. 현재는 박사님 "링크 아는 사람만" 의도에 맞춘 noindex public 방식.
- 레포가 public이므로 **민감정보(실명·가정사) 절대 포함 금지** — 콘텐츠는 이미 호칭 추상화됨(룸 규칙 준수).
- 커스텀 도메인 원하면 추후 `CNAME` 파일 + DNS 설정으로 가능.

---

## 🔒 주간 갱신 = 반드시 `./safe_deploy.sh` (2026-07-03)

외부 공개 후에는 raw `deploy.sh` 대신 **`./safe_deploy.sh`** 로 배포한다.
- 배포 전 민감정보 스캔(실명·연락처·학교·탈북 식별디테일·명명된 사역자) 자동 실행.
- 통과 시에만 push. 실패 시 중단 + `~/.intimyai/NEXTGEN_DEPLOY_BLOCKED` 플래그 + master 알림.
- 미래 주차에 탈북 간증 게스트 실명 등이 재유입돼도 자동 발행 차단.
- 익명화 원칙: 발행 경계에서 실명→직함/'한 …님', 식별 디테일 순화(간증 뼈대 보존).

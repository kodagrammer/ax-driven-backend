# CLI 파이프라인 활용 가이드

터미널 환경에서 `prompts/`와 `templates/`를 파이프(`|`)로 연결하여 사용하는 실무 가이드.
각 시나리오는 **자동 구간**(AI가 생성)과 **사람 확인 구간**(사람이 판단 후 실행)으로 나뉜다.

> **원칙:** 생성은 자동으로, 실행은 사람이.
> 되돌리기 어려운 작업(커밋, 이슈 발행, PR)은 반드시 사람이 확인 후 실행한다.

<br/>

## ⚙️ 사전 준비

#### 필수 도구

| 도구 | 용도 | 설치 확인 |
|------|------|-----------|
| Git | 버전 관리, diff 추출 | `git --version` |
| Claude Code | AI 파이프라인 실행 | `claude --version` |

> Windows는 WSL 환경에서만 동작한다. 상세 호환성은 [README](../README.md#플랫폼-호환성) 참조


#### 선택 도구 (시나리오별)

| 도구 | 용도 | 필요 시나리오 |
|------|------|--------------|
| GitHub CLI (`gh`) | 이슈/마일스톤 생성 | 시나리오 3 (GitHub 전용) |


#### 프로젝트 내 예상 구조

```
my-project/
├── ax-driven/
│   ├── prompts/
│   ├── templates/
│   └── ...
├── src/
└── ...
```

> 프로젝트 배치 방법은 [README Quick Start](../README.md#quick-start) 참조.

<br/>

## 💬 시나리오 1: 커밋 메시지 자동 생성

스테이징된 변경사항을 AI가 분석하여 Conventional Commits 규격의 커밋 메시지를 생성한다.

> **필요 도구:** Git, Claude Code
> **플랫폼:** GitHub / GitLab / Bitbucket 모두 사용 가능

#### 파이프라인 흐름

```
git diff --cached ─→ 커밋 가이드 프롬프트와 결합 ─→ AI 생성 ─→ 임시 파일 저장 ─→ [사람 확인/수정] ─→ 커밋 ─→ 임시 파일 삭제
       자동                    자동              자동         자동           사람 확인     사람 실행      자동
```

#### 명령어

```bash
# [자동 구간] 커밋 메시지를 임시 파일에 저장
mkdir -p ax-driven/tmp
git diff --cached | cat ax-driven/prompts/00-git-commit-guide.md - | claude --print > ax-driven/tmp/commit.md

# [사람 확인 구간] 편집기에서 확인/수정 후 커밋
vi ax-driven/tmp/commit.md
git commit -F ax-driven/tmp/commit.md

# [정리] 커밋 완료 후 임시 파일 삭제
rm ax-driven/tmp/commit.md
```

#### 사람이 확인할 포인트
- type(feat/fix/docs 등)이 변경 내용과 맞는가?
- scope가 적절한가?
- 이슈 번호가 올바른가?

<br/>

## 👁️‍🗨️ 시나리오 2: PR 아키텍처 리뷰

현재 브랜치의 전체 변경사항을 AI 아키텍트가 리뷰한다.

> **필요 도구:** Git, Claude Code
> **플랫폼:** GitHub / GitLab / Bitbucket 모두 사용 가능

#### 파이프라인 흐름

```
git diff main...HEAD ─→ PR 리뷰 프롬프트와 결합 ─→ AI 리뷰 생성 ─→ 임시 파일 저장 ─→ [사람 확인] ─→ 코드 수정 / PR 반영 ─→ 임시 파일 삭제
        자동                     자동               자동           자동         사람 판단          사람 실행            자동
```

#### 명령어

```bash
# [자동 구간] 아키텍처 리뷰를 임시 파일에 저장
mkdir -p ax-driven/tmp
git diff main...HEAD | cat ax-driven/prompts/03-pr-reviewer.md - | claude --print > ax-driven/tmp/review.md

# [사람 확인 구간] 리뷰 결과 확인
vi ax-driven/tmp/review.md

# [정리] 리뷰 반영 완료 후 삭제
rm ax-driven/tmp/review.md
```

#### 사람이 확인할 포인트
- Must Fix 항목이 실제로 문제인가? (False Positive 여부)
- Should Fix 중 현재 스코프에서 처리할 것과 후속 이슈로 뺄 것 분류
- Consider 항목은 팀과 논의가 필요한지 판단

#### 응용: 특정 파일만 리뷰

```bash
git diff main...HEAD -- src/service/PaymentService.java | cat ax-driven/prompts/03-pr-reviewer.md - | claude --print > ax-driven/tmp/review.md
```

<br/>

## 📝 시나리오 3: 작업 명세서 → GitHub 이슈 일괄 생성

작성된 작업 명세서를 AI가 분석하여 마일스톤 + 이슈 생성용 `gh` 명령어를 생성한다.

> **필요 도구:** Git, Claude Code, GitHub CLI (`gh`)
> **플랫폼:** GitHub 전용 — Bitbucket/GitLab 사용 시 해당 플랫폼의 CLI 또는 API로 명령어 교체 필요

#### 파이프라인 흐름

```
작업 명세서 ─→ 이슈 생성기 프롬프트와 결합 ─→ AI가 gh 명령어 생성 ─→ 임시 파일 저장 ─→ [사람 확인] ─→ 명령어 실행 ─→ 임시 파일 삭제
   입력               자동                   자동              자동         사람 판단      사람 실행        자동
```

#### Step 1: 명세서 작성 (사람 작업)

```bash
# 임시 디렉토리에 명세서를 작성한다
mkdir -p ax-driven/tmp
cp ax-driven/templates/03-work-specification.md ax-driven/tmp/spec.md
vi ax-driven/tmp/spec.md
```

#### Step 2: 이슈 명령어 생성 (자동 구간)

```bash
# [자동 구간] 명세서 + 이슈 생성기 프롬프트 → gh 명령어를 임시 파일에 저장
cat ax-driven/prompts/04-issue-generator.md ax-driven/tmp/spec.md | claude --print > ax-driven/tmp/issue.md
```

#### Step 3: 명령어 확인 후 실행 (사람 확인 구간)

```bash
# [사람 확인 구간] 생성된 gh 명령어를 확인/수정
vi ax-driven/tmp/issue.md

# 확인 후 명령어 실행
# (issue.md 안의 gh 명령어를 복사하여 실행)

# [정리] 이슈 생성 완료 후 삭제
rm ax-driven/tmp/issue.md ax-driven/tmp/spec.md
```

#### 사람이 확인할 포인트
- 마일스톤 이름과 설명이 의도와 맞는가?
- 이슈 분할 단위가 적절한가? (너무 크거나 작지 않은가)
- 라벨이 올바르게 분류되었는가?
- 이슈 본문에 누락된 요구사항이 없는가?

<br/>

## ⏩️ 단축 명령어

매번 파이프라인 명령어를 입력하는 대신, `ax-driven.sh`를 source하면 단축 명령어로 실행할 수 있다.

#### 설치

```bash
# ax-driven 디렉토리로 이동 후 source
cd /path/to/ax-driven        # subtree로 가져온 경우
cd /path/to/ax-driven-backend # 레포를 직접 사용하는 경우

source ./scripts/claude/ax-driven.sh
```

매번 source하기 번거로우면 `~/.zshrc` 또는 `~/.bashrc`에 절대경로로 추가한다.

```bash
# 예시: 본인 환경에 맞게 경로 수정
source /Users/kodayoung/Desktop/Projects/github/ax-driven-backend/scripts/claude/ax-driven.sh
```

셸 재시작 또는 `source ~/.zshrc` 후 사용 가능.

> **스크립트를 수정했다면?** `ax-driven.sh`를 커스터마이즈한 후에는 `source`를 다시 실행해야 변경이 반영됩니다.
> ```bash
> source ./scripts/claude/ax-driven.sh
> ```

#### 명령어

| 명령어 | 시나리오 | 동작 |
|--------|----------|------|
| `ai-commit` | 커밋 메시지 생성 | diff → AI 생성 → 편집기에서 확인 → 저장하면 커밋, 마지막 줄 `quit`으로 취소 |
| `ai-review` | PR 리뷰 | diff → AI 리뷰 생성 → 편집기에서 확인 |
| `ai-review develop` | PR 리뷰 (base 지정) | main 대신 다른 브랜치 기준으로 리뷰 |
| `ai-issue` | 이슈 생성 | 명세서 템플릿 → 편집기에서 작성 → AI가 gh 명령어 생성 → 편집기에서 확인 |
| `_ax_done commit` | 임시 파일 정리 | 지정한 항목의 임시 파일 삭제 |
| `_ax_done` | 전체 정리 | `ax-driven/tmp/` 내 모든 임시 파일 삭제 |

#### 사용 예시

```bash
# 커밋 메시지 생성 → 확인 → 커밋
git add src/service/PaymentService.java
ai-commit
# 편집기가 열림 → 내용 확인 → 저장하면 커밋 완료
# 취소하려면 마지막 줄에 quit 작성 후 저장 (임시 파일은 유지됨)

# PR 리뷰
ai-review
# 편집기에서 리뷰 결과 확인
# 반영 완료 후 정리
_ax_done review

# 이슈 생성
ai-issue
# 1) 명세서 템플릿이 열림 → 작성 후 저장
# 2) AI가 gh 명령어 생성 → 편집기에서 확인
# 3) 명령어를 복사하여 터미널에서 실행
# 4) 완료 후 정리
_ax_done issue && _ax_done spec
```

#### 핵심 동작

- **`_ax_find`**: 현재 디렉토리에서 상위로 올라가며 `ax-driven*` 디렉토리를 자동 탐지한다. subtree로 가져온 경우와 레포를 직접 사용하는 경우 모두 동작한다.
- **임시 파일 안전장치**: 이전 작업의 임시 파일이 남아있으면 실행을 중단한다. 임시 파일을 직접 확인한 후 `_ax_done <작업명>`으로 정리해야 다음 실행이 가능하다.
  ```
  [WARN] 작업중이던 항목이 있습니다: ax-driven/tmp/commit.md
    확인: ${EDITOR:-vi} ax-driven/tmp/commit.md
    정리: _ax_done commit
  ```
- **편집기 설정**: 환경변수 `$EDITOR`를 따른다. 미설정 시 `vi`가 기본값.

> macOS(zsh)와 Linux(bash) 모두 동작한다. Windows는 WSL 환경에서 사용 가능.

<br/>

## 🎯 판단 기준 요약

| 구간 | 기준 | 예시 |
|------|------|------|
| **자동** | 되돌리기 쉬움, 생성만 함 | diff 추출, 메시지 생성, 리뷰 텍스트 생성 |
| **사람 확인** | 되돌리기 어려움, 외부에 영향 | git commit, gh issue create, PR 머지 |

> 자동 구간에서 사람이 할 일은 없다. 사람 확인 구간에서의 판단은 1~2초(눈으로 훑기)면 충분하다.
> 병목은 "판단"이 아니라 "판단할 재료를 만드는 시간"이며, 그 시간을 자동 구간이 제거한다.

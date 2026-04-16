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
mkdir -p /tmp/ax-driven
git diff --cached | cat ax-driven/prompts/00-git-commit-guide.md - | claude --print > /tmp/ax-driven/commit.md

# [사람 확인 구간] 편집기에서 확인/수정 후 커밋
vi /tmp/ax-driven/commit.md
git commit -F /tmp/ax-driven/commit.md

# [정리] 커밋 완료 후 임시 파일 삭제
rm /tmp/ax-driven/commit.md
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
mkdir -p /tmp/ax-driven
git diff main...HEAD | cat ax-driven/prompts/03-pr-reviewer.md - | claude --print > /tmp/ax-driven/review.md

# [사람 확인 구간] 리뷰 결과 확인
vi /tmp/ax-driven/review.md

# [정리] 리뷰 반영 완료 후 삭제
rm /tmp/ax-driven/review.md
```

#### 사람이 확인할 포인트
- Must Fix 항목이 실제로 문제인가? (False Positive 여부)
- Should Fix 중 현재 스코프에서 처리할 것과 후속 이슈로 뺄 것 분류
- Consider 항목은 팀과 논의가 필요한지 판단

#### 응용: 특정 파일만 리뷰

```bash
git diff main...HEAD -- src/service/PaymentService.java | cat ax-driven/prompts/03-pr-reviewer.md - | claude --print > /tmp/ax-driven/review.md
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
mkdir -p /tmp/ax-driven
cp ax-driven/templates/03-work-specification.md /tmp/ax-driven/spec.md
vi /tmp/ax-driven/spec.md
```

#### Step 2: 이슈 명령어 생성 (자동 구간)

```bash
# [자동 구간] 명세서 + 이슈 생성기 프롬프트 → gh 명령어를 임시 파일에 저장
cat ax-driven/prompts/04-issue-generator.md /tmp/ax-driven/spec.md | claude --print > /tmp/ax-driven/issue.md
```

#### Step 3: 명령어 확인 후 실행 (사람 확인 구간)

```bash
# [사람 확인 구간] 생성된 gh 명령어를 확인/수정
vi /tmp/ax-driven/issue.md

# 확인 후 명령어 실행
# (issue.md 안의 gh 명령어를 복사하여 실행)

# [정리] 이슈 생성 완료 후 삭제
rm /tmp/ax-driven/issue.md /tmp/ax-driven/spec.md
```

#### 사람이 확인할 포인트
- 마일스톤 이름과 설명이 의도와 맞는가?
- 이슈 분할 단위가 적절한가? (너무 크거나 작지 않은가)
- 라벨이 올바르게 분류되었는가?
- 이슈 본문에 누락된 요구사항이 없는가?

<br/>

## ⏩️ 단축 명령어

매번 파이프라인 명령어를 입력하는 대신, shell alias를 등록하면 단축 명령어로 실행할 수 있다.
단축 명령어 스크립트는 `scripts/claude/ax-driven.sh`에서 제공하며, 아래는 동작 구조만 안내한다.

#### 구조

```bash
# ~/.zshrc 또는 ~/.bashrc에 한 번만 추가
source ~/path/to/ax-driven-scripts/ax-driven.sh
```

```bash
ai-commit     # 시나리오 1: 커밋 메시지 생성 → 편집기 → 확인 후 커밋
ai-review     # 시나리오 2: PR 리뷰 생성 → 편집기
ai-issue      # 시나리오 3: 이슈 명령어 생성 → 편집기
_ax_done <name>  # 작업 완료 후 임시 파일 정리
```

#### 핵심 동작

- **`_ax_find`**: 현재 디렉토리에서 상위로 올라가며 `ax-driven/` 디렉토리를 자동 탐지한다. 하위 디렉토리에서 실행해도 프로젝트 루트의 `ax-driven/`을 찾는다.
- **임시 파일 안전장치**: 임시 파일이 이미 존재하면 실행을 중단하고 아래 메시지를 출력한다.
  ```
  ⚠️  작업중이던 항목이 있습니다: /tmp/ax-driven/commit.md
     확인 후 수동 삭제해주세요: rm /tmp/ax-driven/commit.md
  ```
- **`_ax_done`**: 작업 완료 후 임시 파일을 삭제한다.

> 스크립트의 실제 구현은 `scripts/claude/ax-driven.sh`를 참조한다.
> macOS(zsh)와 Linux(bash) 모두 POSIX 호환으로 하나의 스크립트로 동작한다.
> Windows는 WSL 환경에서 동일하게 사용 가능하다.

<br/>

## 🎯 판단 기준 요약

| 구간 | 기준 | 예시 |
|------|------|------|
| **자동** | 되돌리기 쉬움, 생성만 함 | diff 추출, 메시지 생성, 리뷰 텍스트 생성 |
| **사람 확인** | 되돌리기 어려움, 외부에 영향 | git commit, gh issue create, PR 머지 |

> 자동 구간에서 사람이 할 일은 없다. 사람 확인 구간에서의 판단은 1~2초(눈으로 훑기)면 충분하다.
> 병목은 "판단"이 아니라 "판단할 재료를 만드는 시간"이며, 그 시간을 자동 구간이 제거한다.

# CLI & 프롬프트 체이닝 가이드

터미널 환경에서 `prompts/`와 `templates/`를 파이프(`|`)로 연결하여 사용하는 실무 가이드.
단축 명령어(`ai-commit` 등)와 수동 파이프라인 모두 다룬다.
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
| GitHub CLI (`gh`) | 이슈 생성 | 시나리오 3 (GitHub 전용) |

<br/>

## 🔧 AI tier와 모델 선택

단축 명령어는 작업 특성에 따라 AI tier(`low`/`standard`/`high`)를 사용한다. tier별 모델 매핑은 provider가 결정하며, 현재 기본 provider는 Claude이다.

| 작업 | AI tier | Claude 모델 | 이유 |
|------|---------|-------------|------|
| 브랜치명 생성 | low | haiku | 이슈 제목 → 브랜치명 단순 변환 |
| 커밋 메시지 생성 | standard | sonnet | diff 분석 + 컨벤션 적용 |
| 코드 리뷰 — triage | low | haiku | diff 분류 (cheap routing) |
| 코드 리뷰 — review | triage 결정 | triage 결정 | [상세: Agents & Schemas 가이드](04-agents-and-schemas.md) |
| 이슈 생성 | - | - (AI 미사용) | 명세서 → gh CLI 직접 실행 |

> 수동 파이프라인에서는 `--model` 옵션으로 모델을 직접 지정할 수 있다. 생략하면 Claude Code 기본 모델이 사용된다.
> tier별 timeout 및 모델 매핑은 `scripts/lib/ai.sh`와 `providers/claude.sh`에서 관리한다.

<br/>

## 🌿 시나리오 0: 브랜치 생성

이슈 내용(또는 작업 설명)을 AI가 분석하여 컨벤션에 맞는 브랜치명을 생성한다.

#### 파이프라인 흐름

```
이슈 내용 + 기존 브랜치 목록 ─→ 브랜치 가이드 프롬프트와 결합 ─→ AI 생성 ─→ [사람 확인] ─→ 브랜치 생성
         자동                            자동                자동       사람 확인     사람 실행
```

#### 명령어

```bash
# *️⃣ CLI로 실행
printf '%s\n\n---\n\n## 이슈 정보\n[no-issue] 작업 내용: 로깅 추가\n\n## 기존 브랜치 목록\n%s\n' \
  "$(cat ax-driven/prompts/05-branch-name-guide.md)" \
  "$(git branch -a --format='%(refname:short)')" \
  | claude --print --model haiku

# [사람 확인 구간] 출력된 브랜치명 확인 후 생성
git switch -c feat/no-issue-add-logging
git push -u origin feat/no-issue-add-logging

# ⏩️ 단축키 사용
ai-branch -i no-issue:로깅추가 --from develop
```

#### 사람이 확인할 포인트
- type(feat/fix/docs 등)이 작업 내용과 맞는가?
- 브랜치명이 기존 브랜치와 중복되지 않는가?

<br/>

## 💬 시나리오 1: 커밋 메시지 자동 생성

스테이징된 변경사항을 AI가 분석하여 Conventional Commits 규격의 커밋 메시지를 생성한다.

#### 파이프라인 흐름

```
git diff --cached ─→ 커밋 가이드 프롬프트와 결합 ─→ AI 생성 ─→ 임시 파일 저장 ─→ [사람 확인/수정] ─→ 커밋 ─→ 임시 파일 삭제
       자동                    자동              자동         자동           사람 확인     사람 실행      자동
```

#### 명령어

```bash
# *️⃣ CLI로 실행
# [자동 구간] 커밋 메시지를 임시 파일에 저장 (--model로 모델 지정 가능)
mkdir -p ax-driven/tmp
git diff --cached | cat ax-driven/prompts/00-git-commit-guide.md - | claude --print --model sonnet > ax-driven/tmp/commit.md

# [사람 확인 구간] 편집기에서 확인/수정 후 커밋
vi ax-driven/tmp/commit.md
git commit -F ax-driven/tmp/commit.md

# [정리] 커밋 완료 후 임시 파일 삭제
rm ax-driven/tmp/commit.md

# ⏩️ 단축 명령어 사용
ai-commit
```

#### 사람이 확인할 포인트
- type(feat/fix/docs 등)이 변경 내용과 맞는가?
- scope가 적절한가?
- 이슈 번호가 올바른가?

<br/>

## 👁️‍🗨️ 시나리오 2: 코드 리뷰 (Pre-merge)

PR 생성 전에 로컬 변경사항을 AI가 자체 검열한다.
triage가 diff를 분류하고, 필요 시 전문 subagent(security, test, architecture)를 추가 실행하여 통합 리포트를 생성한다.

#### 파이프라인 흐름

```
diff 수집 ─→ triage (haiku) ─→ Decision JSON ─→ base review ─→ [subagent dispatch] ─→ [collect] ─→ 임시 파일 저장 ─→ [사람 확인] ─→ 코드 수정
  자동           자동              자동            자동             자동(조건부)       자동(조건부)      자동           사람 판단       사람 실행
```

> subagent가 없으면 base review 결과만 출력. subagent가 있으면 base(haiku로 경량화) + subagent 결과를 collector가 취합.
> 상세 구조는 [Agents & Schemas 가이드](04-agents-and-schemas.md) 참조.

#### 명령어

```bash
# ⏩️ 단축 명령어 (기본: staged 변경사항)
ai-review

# 전체 로컬 변경사항 (staged + unstaged)
ai-review --all

# 브랜치 diff (main 대비)
ai-review --branch

# triage Decision JSON만 확인
ai-review --json
```

#### 사람이 확인할 포인트
- critical/high 지적이 실제 문제인가? (오탐 여부)
- medium 항목 중 현재 스코프에서 처리할 것과 후속 이슈로 뺄 것 분류
- Final Verdict가 `request_changes`이면 반드시 수정 후 재실행

<br/>

## 📝 시나리오 3: 작업 명세서 → GitHub 이슈 생성

작성된 작업 명세서를 GitHub 이슈로 직접 생성한다. AI 호출 없이 shell만으로 동작한다.
1 spec = 1 issue. 명세서 내용이 이슈 body로 그대로 들어간다.

#### 파이프라인 흐름

```
작업 명세서 ─→ title 추출 ─→ [사람 미리보기] ─→ gh issue create (body = spec 전체)
   입력          자동           사람 확인              자동
```

#### 명세서 작성 규칙

명세서는 `templates/03-work-specification.md` 템플릿을 기반으로 작성한다.
`ai-issue`는 제목 헤더(`# ...`)에서 이슈 title을 추출하므로, 아래 규칙을 준수해야 한다.

| 규칙 | 설명 | 예시 |
|------|------|------|
| 제목 헤더 필수 | 첫 번째 `#` 헤더에서 제목 추출 → `{type}: {제목}` | `# 📄 Work Specification: ai-review 개편` → `enhancement: ai-review 개편` |
| 나머지 자유 | 본문은 그대로 이슈 body로 들어간다 | Context, Tasks, DoD 등 |

#### 명령어

```bash
# 단일 이슈 (spec 없으면 템플릿 제공 → 작성 → 재실행)
ai-issue

# 일괄 생성 (tmp/에 spec01.md, spec02.md ... 배치 후)
ai-issue

# 정리
_ax_done
```

#### type 메타데이터

명세서 상단 HTML 주석에 `type:` 을 지정하면 이슈 제목과 label이 자동 설정된다.
`templates/03-work-specification.md` 템플릿을 기반으로 작성하는 것을 권장한다.
**type 미지정 시 enhancement로 자동 지정된다.**

이슈 제목 포맷: `{type}: {제목}` (예: `feature: ai-test 엣지케이스 추출`)

```markdown
<!-- ai-issue 메타데이터 (미지정 시 enhancement)
type: bug
-->
```

| type 값 | title 예시 | 기본 label |
|---------|-----------|-----------|
| (미지정) | `enhancement: ...` | enhancement |
| `feature` | `feature: ...` | enhancement |
| `bug` | `bug: ...` | bug |
| `refactor` | `refactor: ...` | enhancement |
| `docs` | `docs: ...` | documentation |
| `test` | `test: ...` | enhancement |

> **label 커스텀:** `config/issue-labels.conf`에서 `type=label` 매핑을 수정할 수 있다.
> 레포에 커스텀 label이 있다면 이 파일만 수정하면 된다. (예: `feature=new-feature`)

#### 사람이 확인할 포인트
- 미리보기에서 이슈 제목이 의도와 맞는가?
- 명세서 내용(body)에 누락된 요구사항이 없는가?

<br/>

> 단축 명령어(`ai-branch`, `ai-commit` 등) 설치 및 사용법은 [README Quick Start](../README.md#-quick-start) 참조.

<br/>

## 🎯 판단 기준 요약

| 구간 | 기준 | 예시 |
|------|------|------|
| **자동** | 되돌리기 쉬움, 생성만 함 | diff 추출, 메시지 생성, 리뷰 텍스트 생성 |
| **사람 확인** | 되돌리기 어려움, 외부에 영향 | git commit, gh issue create, PR 머지 |

> 자동 구간에서 사람이 할 일은 없다. 사람 확인 구간에서의 판단은 1~2초(눈으로 훑기)면 충분하다.
> 병목은 "판단"이 아니라 "판단할 재료를 만드는 시간"이며, 그 시간을 자동 구간이 제거한다.

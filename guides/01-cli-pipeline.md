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
| GitHub CLI (`gh`) | 이슈/마일스톤 생성 | 시나리오 3 (GitHub 전용) |

<br/>

## 🔧 모델 선택

수동 파이프라인에서는 `--model` 옵션으로 모델을 지정할 수 있다. 생략하면 Claude Code 기본 모델이 사용된다.

| 작업 | 권장 모델 | 이유 |
|------|----------|------|
| 커밋 메시지 생성 | sonnet | diff 분석 + 컨벤션 적용 |
| PR 아키텍처 리뷰 | opus | 코드 맥락을 깊이 읽어야 하는 작업 |
| 이슈 명령어 생성 | haiku | 명세서 → gh CLI 포맷 변환 |
| 브랜치명 생성 | haiku | 이슈 제목 → 브랜치명 단순 변환 |

> 단축 명령어(`ai-commit` 등)는 위 모델이 이미 내장되어 있다.

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

## 👁️‍🗨️ 시나리오 2: PR 아키텍처 리뷰

현재 브랜치의 전체 변경사항을 AI 아키텍트가 리뷰한다.

#### 파이프라인 흐름

```
git diff main...HEAD ─→ PR 리뷰 프롬프트와 결합 ─→ AI 리뷰 생성 ─→ 임시 파일 저장 ─→ [사람 확인] ─→ 코드 수정 / PR 반영 ─→ 임시 파일 삭제
        자동                     자동               자동           자동         사람 판단          사람 실행            자동
```

#### 명령어

```bash
# *️⃣ CLI로 실행
# [자동 구간] 아키텍처 리뷰를 임시 파일에 저장
mkdir -p ax-driven/tmp
git diff main...HEAD | cat ax-driven/prompts/03-pr-reviewer.md - | claude --print --model opus > ax-driven/tmp/review.md

# [사람 확인 구간] 리뷰 결과 확인
vi ax-driven/tmp/review.md

# [정리] 리뷰 반영 완료 후 삭제
rm ax-driven/tmp/review.md

# ⏩️ 단축키 사용
ai-review
```

#### 사람이 확인할 포인트
- Must Fix 항목이 실제로 문제인가? (False Positive 여부)
- Should Fix 중 현재 스코프에서 처리할 것과 후속 이슈로 뺄 것 분류
- Consider 항목은 팀과 논의가 필요한지 판단

#### 응용: 특정 파일만 리뷰

```bash
git diff main...HEAD -- src/service/PaymentService.java | cat ax-driven/prompts/03-pr-reviewer.md - | claude --print --model opus > ax-driven/tmp/review.md
```

<br/>

## 📝 시나리오 3: 작업 명세서 → GitHub 이슈 일괄 생성

작성된 작업 명세서를 AI가 분석하여 마일스톤 + 이슈 생성용 `gh` 명령어를 생성한다.

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
# *️⃣ CLI로 실행
# [자동 구간] 명세서 + 이슈 생성기 프롬프트 → gh 명령어를 임시 파일에 저장
cat ax-driven/prompts/04-issue-generator.md ax-driven/tmp/spec.md | claude --print --model haiku > ax-driven/tmp/issue.md

# ⏩️ 단축키 사용
ai-issue
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

> 단축 명령어(`ai-branch`, `ai-commit` 등) 설치 및 사용법은 [README Quick Start](../README.md#-quick-start) 참조.

<br/>

## 🎯 판단 기준 요약

| 구간 | 기준 | 예시 |
|------|------|------|
| **자동** | 되돌리기 쉬움, 생성만 함 | diff 추출, 메시지 생성, 리뷰 텍스트 생성 |
| **사람 확인** | 되돌리기 어려움, 외부에 영향 | git commit, gh issue create, PR 머지 |

> 자동 구간에서 사람이 할 일은 없다. 사람 확인 구간에서의 판단은 1~2초(눈으로 훑기)면 충분하다.
> 병목은 "판단"이 아니라 "판단할 재료를 만드는 시간"이며, 그 시간을 자동 구간이 제거한다.

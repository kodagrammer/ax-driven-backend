# Claude Code Hooks 활용 가이드

Claude Code 세션 내에서 도구 호출 전/후에 쉘 명령어를 자동 실행하는 Hook 설정 가이드.
코드 수정 후 린트/포맷을 자동으로 고쳐주고, 커밋 시 팀 컨벤션을 주입하는 **보조 역할**에 집중한다.

> **Git Hooks vs Claude Code Hooks**
>
> | | Git Hooks | Claude Code Hooks |
> |---|---|---|
> | **역할** | 차단 / 검증 | 자동 수정 / 보조 |
> | **동작** | 규칙 위반 시 커밋 중단 | 커밋 전에 미리 고쳐줌 |
> | **트리거** | git 명령어 (`commit`, `push`) | Claude Code 내부 이벤트 (도구 호출 전/후) |
> | **동작 환경** | 터미널 어디서든 | Claude Code 세션 내에서만 |
>
> 둘은 대체 관계가 아니라 **보완 관계**다.
> Claude Code Hooks가 먼저 자동 수정하고, Git Hooks가 최종 검증한다.

<br/>

## ⚙️ 설정 방법

Claude Code Hooks는 `settings.json`에 정의한다.

| 위치 | 범위 | 파일 |
|------|------|------|
| `~/.claude/settings.json` | 전역 (모든 프로젝트) | 개인 설정 |
| `.claude/settings.json` | 프로젝트 (git에 커밋) | 팀 공유 설정 |
| `.claude/settings.local.json` | 프로젝트 로컬 | 개인 오버라이드 (gitignore 대상) |

> 팀 규칙은 `.claude/settings.json`에 넣어서 git으로 공유한다.
> 개인 환경에만 필요한 설정은 `settings.local.json`에 넣는다.

<br/>

## 📐 설정 구조

```json
{
  "hooks": {
    "<이벤트명>": [
      {
        "matcher": "<도구 필터>",
        "hooks": [
          {
            "type": "command",
            "command": "실행할 쉘 명령어",
            "timeout": 600
          }
        ]
      }
    ]
  }
}
```

#### 주요 이벤트

| 이벤트 | 시점 | 용도 |
|--------|------|------|
| `PreToolUse` | 도구 실행 **전** | 입력 수정, 차단 가능 |
| `PostToolUse` | 도구 실행 **후** | 결과 검증, 후처리 |
| `UserPromptSubmit` | 사용자 프롬프트 제출 시 | 프롬프트 전처리 |
| `Notification` | 알림 발생 시 | 외부 연동 |

#### Matcher 패턴

| 패턴 | 의미 | 예시 |
|------|------|------|
| 생략 또는 `""` | 모든 도구 | - |
| 도구명 | 정확히 해당 도구 | `Bash`, `Write` |
| `\|` 구분 | 여러 도구 | `Edit\|Write` |

#### Exit Code

| Exit Code | 동작 |
|-----------|------|
| `0` | 성공 — 계속 진행 |
| `2` | **차단** — stderr 메시지를 Claude에 전달 |
| 그 외 | 에러이나 차단하지 않음 — 계속 진행 |

#### 토큰 비용

Hook 타입에 따라 토큰 소모 여부가 다르다.

| Hook | 토큰 소모 | 이유 |
|------|----------|------|
| PostToolUse (lint --fix 등) | **없음** | 쉘 명령어만 실행, Claude에 결과를 돌려주지 않음 |
| PreToolUse (컨벤션 주입 등) | **있음** | `additionalContext`로 문서를 Claude 컨텍스트에 주입하므로 해당 문서 분량만큼 입력 토큰 증가 |

> 워크플로우 2(커밋 컨벤션 주입)는 커밋할 때마다 `00-git-commit-guide.md` 전체가 컨텍스트에 추가된다.
> 토큰 비용이 부담된다면 이 Hook은 비활성화하고, `.clauderules`에 커밋 규칙을 직접 명시하는 방법도 있다.

<br/>

## 1️⃣ 워크플로우: 파일 수정 후 린트/포맷 자동 실행

Claude Code가 파일을 수정(`Edit`, `Write`)한 후 린트와 포맷터를 자동으로 실행한다.
사람이 별도로 `lint --fix`를 돌릴 필요 없이, 수정된 파일이 항상 포맷에 맞는 상태로 유지된다.

#### 흐름

```
Claude Code가 파일 수정 (Edit/Write)
  → PostToolUse Hook 트리거
  → lint --fix, format 자동 실행
  → 수정된 상태로 다음 작업 진행
```

#### 설정 예시

프로젝트 스택에 맞게 command를 교체한다.

**JavaScript/TypeScript 프로젝트:**

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "npx eslint --fix \"$TOOL_INPUT_FILE_PATH\" 2>/dev/null; npx prettier --write \"$TOOL_INPUT_FILE_PATH\" 2>/dev/null; exit 0",
            "timeout": 30000
          }
        ]
      }
    ]
  }
}
```

**Java/Kotlin 프로젝트 (Spotless):**

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "./gradlew spotlessApply 2>/dev/null; exit 0",
            "timeout": 60000
          }
        ]
      }
    ]
  }
}
```

**Python 프로젝트:**

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "ruff check --fix \"$TOOL_INPUT_FILE_PATH\" 2>/dev/null; ruff format \"$TOOL_INPUT_FILE_PATH\" 2>/dev/null; exit 0",
            "timeout": 30000
          }
        ]
      }
    ]
  }
}
```

> `exit 0`을 끝에 붙이는 이유: 린트 대상이 아닌 파일(README.md 등)에서 에러가 나도 Claude Code 작업을 중단시키지 않기 위함.

<br/>

## 2️⃣ 워크플로우: 커밋 시 팀 컨벤션 자동 주입

Claude Code가 `git commit`을 실행하기 전에, 커밋 메시지 가이드(`prompts/00-git-commit-guide.md`)를 컨텍스트로 주입한다.
AI가 생성하는 커밋 메시지도 팀 컨벤션을 따르도록 보장한다.

#### 흐름

```
Claude Code가 git commit 실행 시도
  → PreToolUse Hook 트리거
  → 커밋 가이드를 additionalContext로 주입
  → Claude가 가이드를 참고하여 커밋 메시지 작성
  → Git Hook(commit-msg)이 최종 포맷 검증
```

#### 설정 예시

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "echo '$TOOL_INPUT' | grep -q 'git commit' && echo '{\"hookSpecificOutput\":{\"additionalContext\":'$(cat \"$CLAUDE_PROJECT_DIR/prompts/00-git-commit-guide.md\" | jq -Rs .)'}}' || exit 0",
            "timeout": 5000
          }
        ]
      }
    ]
  }
}
```

> 이 Hook은 **보조**다. 컨벤션을 "알려주는" 역할만 하고, 최종 검증은 Git Hook(`commit-msg`)이 담당한다.

<br/>

## 🔗 Git Hooks와의 병행 전략

두 Hook 시스템은 서로 다른 시점에 동작하며, 함께 사용할 때 가장 효과적이다.

#### 실행 순서

```
Claude Code 세션에서 코드 수정 → 커밋 → push 시:

1. [Claude Code Hook] PostToolUse   — 파일 수정 후 lint --fix 자동 실행
2. [Claude Code Hook] PreToolUse    — git commit 전 커밋 가이드 주입
3. [Git Hook]         pre-commit    — 민감 파일, 충돌 마커, 대용량 파일 차단
4. [Git Hook]         commit-msg    — 커밋 메시지 포맷 최종 검증
5. [Git Hook]         pre-push      — remote update, diverge 감지, main 보호
```

#### 역할 분리 원칙

| 단계 | 담당 | 역할 | 실패 시 |
|------|------|------|---------|
| 자동 수정 | Claude Code Hooks | lint --fix, format, 컨벤션 주입 | 에러 무시, 계속 진행 |
| 최종 검증 | Git Hooks | 포맷 검증, 민감 파일 차단, diverge 감지 | 커밋/push 중단 |

> Claude Code Hooks가 미리 고쳐주기 때문에, Git Hooks에서 걸리는 빈도가 줄어든다.
> 하지만 Git Hooks는 항상 마지막 방어선으로 남겨둔다 — Claude Code 없이 수동 커밋할 때도 동작해야 하므로.

<br/>

## 📋 설정 파일 예시

프로젝트에 바로 적용할 수 있는 전체 설정 예시는 `hooks/claude/settings-example.json`을 참조한다.

```bash
# 프로젝트에 적용
cp hooks/claude/settings-example.json .claude/settings.json
```

> 스택별 lint/format 명령어만 교체하면 된다.

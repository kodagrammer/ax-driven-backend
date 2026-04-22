# AX-Driven Backend Workspace

백엔드 개발 프로세스에 AI를 체계적으로 통합하기 위한 프롬프트·템플릿·자동화 워크스페이스.
이 레포지토리를 포크하여 프로젝트 내부에 `ax-driven/` 디렉토리로 배치하면, 커밋·리뷰·이슈 생성 등의 워크플로우를 CLI 파이프라인으로 자동화할 수 있다.

<br/>

## 🙋🏻‍♀️ 이런 사람을 위한 프로젝트

- 터미널 중심으로 개발하는 백엔드 엔지니어
- AI를 코드 생성기가 아닌 **아키텍처 리뷰어·QA·PM 보조 도구**로 활용하고 싶은 사람
- 팀 컨벤션에 맞게 프롬프트를 커스터마이즈하고, 프로젝트별로 관리하고 싶은 사람

<br/>

## ⚙️ 필요 도구

| 도구 | 필수/선택 | 용도 |
|------|----------|------|
| Git | 필수 | 버전 관리, diff 추출 |
| Claude Code | 필수 | AI 파이프라인 실행 (`claude --print`) |
| GitHub CLI (`gh`) | 선택 | 이슈·마일스톤 생성 (GitHub 전용) |

> Git과 Claude Code만 있으면 핵심 기능(커밋, 리뷰)은 어떤 플랫폼에서든 동작한다.
> **Windows는 WSL(Windows Subsystem for Linux) 환경에서만 동작한다.**

<br/>

## 🎯 제공 기능

| 방식 | 역할 | 상세 가이드 |
|------|------|------------|
| **프롬프트 체이닝** (`scripts/`, `prompts/`) | 커밋 메시지 생성, PR 리뷰, 이슈 생성 등을 AI에게 위임 | [CLI & 프롬프트 체이닝 가이드](guides/01-cli-pipeline.md) |
| **Git Hooks** (`hooks/git/`) | 커밋 컨벤션 검증, 민감 파일 차단, push 전 원격 동기화 | [Git Hooks 가이드](guides/02-git-hooks.md) |
| **Claude Code Hooks** (`hooks/claude/`) | Claude Code 세션 내 lint 자동 실행, 커밋 규칙 주입 | [Claude Code Hooks 가이드](guides/03-claude-code-hooks.md) |

> **원칙:** 생성은 자동으로, 실행은 사람이. 되돌리기 어려운 작업(커밋, 이슈 발행, PR)은 반드시 사람이 확인 후 실행한다.

<br/>

## 🚀 Quick Start

### 1. 프로젝트에 배치

```bash
# git subtree로 프로젝트에 추가 (git 충돌 없음, 팀원 추가 작업 없음)
cd my-project
git subtree add --prefix=ax-driven https://github.com/{your-org}/ax-driven-backend.git main --squash

# 업스트림 업데이트 받기 (포크 원본에 변경이 있을 때)
git subtree pull --prefix=ax-driven https://github.com/{your-org}/ax-driven-backend.git main --squash
```

> **왜 subtree인가?** `git clone`하면 레포 안에 레포가 되어 git이 꼬인다.
> subtree는 하나의 레포로 합쳐지므로, 팀원은 그냥 `git clone`하면 `ax-driven/`이 포함되어 있다.

### 2. 프롬프트 체이닝 실행

`ax-driven.sh`를 source하면 단축 명령어를 사용할 수 있다.

```bash
# 단축 명령어 활성화
source ax-driven/scripts/claude/ax-driven.sh

# 영구 등록 (선택)
echo 'source /absolute/path/to/ax-driven/scripts/claude/ax-driven.sh' >> ~/.zshrc
```

#### 명령어 목록

| 명령어 | 하는 일 | 사용 모델 |
|--------|---------|----------|
| `ai-branch -i <이슈링크or이슈내용> [--from <브랜치명>]` | 이슈 기반 브랜치명 생성 → 확인 → 생성 | haiku |
| `ai-commit` | staged diff → 커밋 메시지 생성 → 편집기 확인 → 커밋 | sonnet |
| `ai-review [base]` | diff → 아키텍처 리뷰 생성 → 편집기 확인 | opus |
| `ai-issue` | 명세서 작성 → gh 명령어 생성 → 편집기 확인 | haiku |
| `_ax_done [name]` | 임시 파일 정리 (`commit`, `review`, `issue`, `spec` 또는 전체) | - |

#### 사용 예시

```bash
# 브랜치 생성
ai-branch -i https://github.com/owner/repo/issues/3
ai-branch -i no-issue:기능정의서추가 --from develop

# 커밋
git add src/service/PaymentService.java
ai-commit
# 편집기가 열림 → 확인 → 저장하면 커밋 / 취소는 마지막 줄에 quit 입력

# PR 리뷰
ai-review              # main 기준
ai-review develop      # develop 기준
_ax_done review        # 리뷰 반영 후 정리

# 이슈 생성
ai-issue
# 1) 명세서 작성 → 2) gh 명령어 생성 → 3) 확인 후 실행
_ax_done issue && _ax_done spec
```

### 3. (선택) 수동 CLI 파이프라인

단축 명령어 없이 직접 파이프라인을 실행할 수도 있다. `--model` 옵션으로 모델을 지정할 수 있다.

```bash
# 커밋 메시지 생성
git diff --cached | cat ax-driven/prompts/00-git-commit-guide.md - | claude --print --model sonnet

# PR 아키텍처 리뷰
git diff main...HEAD | cat ax-driven/prompts/03-pr-reviewer.md - | claude --print --model opus
```

> 시나리오별 상세 사용법, 임시 파일 패턴 안내는 [CLI & 프롬프트 체이닝 가이드](guides/01-cli-pipeline.md) 참조.

### 4. (선택) Git Hooks 설치

```bash
sh ax-driven/hooks/git/install.sh    # 설치
sh ax-driven/hooks/git/uninstall.sh  # 해제
```

> 상세 설정은 [Git Hooks 가이드](guides/02-git-hooks.md) 참조.

### 5. (선택) Claude Code Hooks 설정

```bash
cp ax-driven/hooks/claude/settings-example.json .claude/settings.json
```

> 상세 설정은 [Claude Code Hooks 가이드](guides/03-claude-code-hooks.md) 참조.

### 6. (선택) IDE 연동

| IDE | 방법 |
|-----|------|
| IntelliJ | `AI_INSTRUCTIONS.md`에 `prompts/01-system-instructions.md` 복사 |
| VS Code | `.github/copilot-instructions.md`에 복사 또는 Continue 플러그인 `systemMessage` 등록 |
| Cursor | `.cursorrules`에 복사 |

<br/>

## 📁 디렉토리 구조

```
ax-driven/
├── prompts/              AI에게 전달하는 역할·규칙 프롬프트
├── templates/            AI 출력물의 마크다운 포맷 정의
├── guides/               실무 활용 가이드
├── hooks/
│   ├── git/              Git Hooks 스크립트
│   └── claude/           Claude Code Hooks 설정
├── scripts/
│   └── claude/           프롬프트 체이닝 단축 명령어 스크립트
└── workflows/            GitHub Actions 워크플로우 템플릿
```

| 디렉토리 | 파이프라인 참조 | 삭제 시 영향 |
|----------|----------------|-------------|
| `prompts/` | **직접 참조** | 파이프라인 동작 안 함 |
| `templates/` | **직접 참조** | 해당 템플릿 시나리오 동작 안 함 |
| `guides/` | 참조 안 함 | 영향 없음 |
| `hooks/git/` | 참조 안 함 | 커밋 메시지 검증만 해제 |
| `hooks/claude/` | 참조 안 함 | Claude Hook 자동화만 해제 |
| `scripts/claude/` | 참조 안 함 | alias만 사용 불가, 수동 명령어는 동작 |
| `workflows/` | 참조 안 함 | CI/CD 자동화만 해제 |

> 의존 방향은 항상 단방향. 사용하지 않는 AI 도구의 디렉토리는 삭제해도 다른 기능에 영향 없음.

<br/>

## 👥 팀에서 사용하기

1. 이 레포를 **포크**한다
2. `prompts/`, `templates/`를 팀 컨벤션에 맞게 수정한다
3. 각 프로젝트에 `git subtree add`로 배치한다
4. 같은 팀은 같은 포크를 사용하여 컨벤션을 통일한다

```bash
# 팀 A: A팀 포크를 프로젝트에 추가
cd project-x
git subtree add --prefix=ax-driven https://github.com/team-a/ax-driven-backend.git main --squash

# 팀 B: B팀 포크를 프로젝트에 추가
cd project-y
git subtree add --prefix=ax-driven https://github.com/team-b/ax-driven-backend.git main --squash
```

> 명령어(`ai-commit` 등)는 동일하지만, 프롬프트 내용은 프로젝트마다 다를 수 있다.

<br/>

## 🌐 플랫폼 호환성

| 기능 | GitHub | GitLab | Bitbucket |
|------|--------|--------|-----------|
| 브랜치 생성 | O | O (`no-issue:` only) | O (`no-issue:` only) |
| 커밋 메시지 생성 | O | O | O |
| PR 아키텍처 리뷰 | O | O | O |
| 이슈 일괄 생성 | O (`gh`) | CLI 교체 필요 | CLI 교체 필요 |
| Git Hooks | O | O | O |
| CI/CD 워크플로우 | O (Actions) | 템플릿 교체 필요 | 템플릿 교체 필요 |

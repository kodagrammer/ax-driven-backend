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

#### 플랫폼 호환성

| 기능 | GitHub | GitLab | Bitbucket |
|------|--------|--------|-----------|
| 커밋 메시지 생성 | O | O | O |
| PR 아키텍처 리뷰 | O | O | O |
| 이슈 일괄 생성 | O (`gh`) | CLI 교체 필요 | CLI 교체 필요 |
| Git Hooks | O | O | O |
| CI/CD 워크플로우 | O (Actions) | 템플릿 교체 필요 | 템플릿 교체 필요 |

> Git과 Claude Code만 있으면 핵심 기능(커밋, 리뷰)은 어떤 플랫폼에서든 동작한다.
> **Windows는 WSL(Windows Subsystem for Linux) 환경에서만 동작한다.** WSL 내부에서 프로젝트를 clone하여 작업할 것.

<br/>

## 🎯 제공 기능

이 워크스페이스는 세 가지 방식으로 AI를 개발 워크플로우에 통합한다.

#### 1️⃣ CLI 파이프라인 (`scripts/`)

프롬프트와 diff를 파이프(`|`)로 연결하여 AI를 호출하는 방식.

- **목적:** 커밋 메시지 생성, PR 리뷰, 이슈 생성 등을 AI에게 위임
- **특징:** 필요한 입력만 전달하므로 토큰 소모가 적고, 매번 독립 실행되어 컨텍스트가 누적되지 않음
- **적합한 작업:** 반복적이고 패턴이 명확한 작업 (커밋, 리뷰, 이슈 생성)
- **원칙:** 생성은 자동, 실행은 사람이 확인 후 진행

<br/>

#### 2️⃣ Git Hooks (`hooks/git/`)

git 이벤트(커밋, 푸시 등)에 자동으로 반응하는 스크립트.

- **목적:** 수동 커밋 시 컨벤션 검증, 민감 파일 커밋 방지, push 전 원격 상태 확인
- **특징:** AI를 호출하지 않으므로 토큰 소모 없음, git만 있으면 동작
- **적합한 작업:** 컨벤션 강제, 실수 방지 등 규칙 기반 검증
- **원칙:** 생성이 아닌 검증·보조 역할

| Hook | 실행 시점 | 검증 항목 |
|------|----------|----------|
| `pre-commit` | 커밋 직전 | 민감 파일(.env, *.pem 등), 충돌 마커 잔류, 대용량 파일(5MB), 디버그 코드(warning) |
| `commit-msg` | 메시지 작성 후 | Conventional Commits 포맷, type 허용값, subject 50자, body 72자(warning) |
| `pre-push` | push 직전 | 원격 브랜치 최신화(`remote update --prune`), diverge 감지, main/master 직접 push 차단 |

```bash
# 설치
sh hooks/git/install.sh

# 해제
sh hooks/git/uninstall.sh
```

<br/>

#### 3️⃣ Claude Code Hooks (`hooks/claude/`)

Claude Code 내부 이벤트(도구 호출 전/후 등)에 반응하는 설정.

- **목적:** Claude Code로 작업할 때 팀 규칙을 자동으로 적용
- **특징:** Claude Code를 통해 작업할 때만 동작, 일반 터미널 명령어에서는 무관
- **적합한 작업:** Claude Code 사용 시 린트 자동 실행, 커밋 규칙 강제 등

<br/>

#### 언제 뭘 쓰는가

| 상황 | 추천 방식 | 이유 |
|------|----------|------|
| 커밋 메시지를 AI가 만들어주길 원할 때 | CLI 파이프라인 | 사람이 확인 후 커밋, 토큰 절약 |
| 내가 쓴 커밋 메시지가 컨벤션에 맞는지 체크 | Git Hooks | AI 호출 없이 즉시 검증 |
| Claude Code로 작업 중 자동으로 규칙 적용 | Claude Code Hooks | Claude Code 세션 내에서만 동작 |
| 복잡한 설계 논의, 디버깅 | Claude Code 대화 | 맥락이 필요한 작업은 대화가 적합 |

<br/>

## 📁 디렉토리 구조

```
ax-driven/
├── prompts/              AI에게 전달하는 역할·규칙 프롬프트
├── templates/            AI 출력물의 마크다운 포맷 정의
├── guides/               CLI 파이프라인 등 실무 활용 가이드
├── hooks/
│   ├── git/              Git Hooks 스크립트 (커밋 메시지 포맷 검증·보조)
│   └── claude/           Claude Code Hooks 설정
├── scripts/
│   └── claude/           Claude CLI 기반 단축 명령어 스크립트 (커밋 메시지 생성, PR 리뷰 등)
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

## 🚀 Quick Start

#### 1. 프로젝트에 배치

```bash
# git subtree로 프로젝트에 추가 (git 충돌 없음, 팀원 추가 작업 없음)
cd my-project
git subtree add --prefix=ax-driven https://github.com/{your-org}/ax-driven-backend.git main --squash

# 업스트림 업데이트 받기 (포크 원본에 변경이 있을 때)
git subtree pull --prefix=ax-driven https://github.com/{your-org}/ax-driven-backend.git main --squash
```

> **왜 subtree인가?** `git clone`하면 레포 안에 레포가 되어 git이 꼬인다.
> subtree는 하나의 레포로 합쳐지므로, 팀원은 그냥 `git clone`하면 `ax-driven/`이 포함되어 있다.

#### 2. CLI 파이프라인 사용

프로젝트 루트에서 실행한다. 모든 경로는 상대경로 기준.

```bash
# 커밋 메시지 자동 생성
git diff --cached | cat ax-driven/prompts/00-git-commit-guide.md - | claude --print

# PR 아키텍처 리뷰
git diff main...HEAD | cat ax-driven/prompts/03-pr-reviewer.md - | claude --print
```

> 시나리오별 상세 사용법, 임시 파일 패턴, 단축 명령어 안내는 [CLI 파이프라인 가이드](guides/01-cli-pipeline.md) 참조.

#### 3. IDE 연동 (선택사항)

터미널 외에 IDE에서도 프롬프트를 활용할 수 있다.

| IDE | 방법 |
|-----|------|
| IntelliJ | `AI_INSTRUCTIONS.md`에 `prompts/01-system-instructions.md` 복사 |
| VS Code | `.github/copilot-instructions.md`에 복사 또는 Continue 플러그인 `systemMessage` 등록 |
| Cursor | `.cursorrules`에 복사 |

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

## 📢 상세 가이드

| 가이드 | 내용 | 상태 |
|--------|------|------|
| [CLI 파이프라인](guides/01-cli-pipeline.md) | 시나리오별 사용법, 임시 파일 패턴, 단축 명령어 | 작성 완료 |
| [Git Hooks](guides/02-git-hooks.md) | 커밋 메시지 포맷 검증, 민감 파일·충돌 마커 방지, push 전 원격 동기화 | 작성 완료 |
| [Claude Code Hooks](guides/03-claude-code-hooks.md) | 파일 수정 후 린트/포맷 자동 실행, 커밋 시 컨벤션 주입 | 작성 완료 |
| 프롬프트 체이닝 스크립트 | ai-commit, ai-review, ai-issue 단축 명령어 (AI 생성 → 사람 확인 → 실행) | 예정 |
| GitHub Actions | PR 자동 리뷰, 이슈 라벨링 워크플로우 | 예정 |
| 프롬프트 품질 검증 CI | 필수 섹션 존재 여부, 포맷 일관성 린트 | 예정 |

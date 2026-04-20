# Git Hooks 활용 가이드

수동 커밋 시 컨벤션 검증, 민감 파일 커밋 방지, push 전 원격 상태 확인을 자동화하는 Git Hooks 가이드.
AI를 호출하지 않으므로 토큰 소모가 없으며, git만 있으면 동작한다.

> **원칙:** 검증과 보조만 한다. 커밋 메시지 생성은 `scripts/`의 역할이다.
> AI가 생성한 커밋은 이미 컨벤션을 따르므로, 이 Hook은 **사람이 직접 커밋할 때** 실수를 잡아내는 안전망이다.

<br/>

## ⚙️ 설치 / 해제

```bash
# 설치 — hooks/git/ 의 스크립트를 .git/hooks/ 에 심볼릭 링크로 연결
sh hooks/git/install.sh

# 해제 — 심볼릭 링크만 제거 (원본 스크립트는 유지)
sh hooks/git/uninstall.sh
```

> subtree로 프로젝트에 배치한 경우: `sh ax-driven/hooks/git/install.sh`

<br/>

## 🔍 Hook 구성

| Hook | 실행 시점 | 역할 |
|------|----------|------|
| `pre-commit` | `git commit` 직전 | 커밋 대상 파일 검증 |
| `commit-msg` | 커밋 메시지 작성 후 | 메시지 포맷 검증 |
| `pre-push` | `git push` 직전 | 원격 상태 확인 및 보호 |

<br/>

## 1️⃣ pre-commit — 커밋 대상 파일 검증

스테이징된 파일을 검사하여 커밋하면 안 되는 파일이나 상태를 잡아낸다.

#### 검증 항목

| 항목 | 수준 | 설명 |
|------|------|------|
| 민감 파일 | **Error** | `.env`, `credentials.json`, `*.pem`, `*.key` 등 |
| 충돌 마커 | **Error** | `<<<<<<<`, `=======`, `>>>>>>>` 가 파일에 남아있는 경우 |
| 대용량 파일 | **Error** | 5MB 초과 파일 (바이너리, 덤프 등) |
| 디버그 코드 | **Warning** | `console.log`, `debugger`, `System.out.println`, `binding.pry`, `breakpoint()` 등 |

#### 출력 예시

```
[ERROR] 민감 파일이 스테이징되어 있습니다: config/.env.production
  .gitignore에 추가하거나 git reset HEAD config/.env.production 로 제거해주세요.

[WARNING] 디버그 코드가 감지되었습니다.
  src/service/PaymentService.java:
    42:    System.out.println("debug: amount=" + amount);

  (Warning이므로 커밋은 중단되지 않습니다. 불필요한 코드라면 제거 후 다시 커밋해주세요.)
```

#### 디버그 코드 패턴 확장

`hooks/git/pre-commit`의 grep 패턴에 추가하면 된다.

```
# 현재 지원 패턴
console\.log|debugger;|System\.out\.print|binding\.pry|import pdb|breakpoint\(\)

# 예시: Kotlin의 println 추가
console\.log|debugger;|System\.out\.print|binding\.pry|import pdb|breakpoint\(\)|println\(
```

<br/>

## 2️⃣ commit-msg — 커밋 메시지 포맷 검증

커밋 메시지가 Conventional Commits 규격(`prompts/00-git-commit-guide.md`)을 따르는지 검증한다.

#### 올바른 형식

```
<type>(<scope>): <subject> (#이슈번호)
<type>(<scope>): <subject> (no-issue)
```

#### 검증 항목

| 항목 | 수준 | 기준 |
|------|------|------|
| subject 형식 | **Error** | `type(scope): subject (#N)` 또는 `(no-issue)` 패턴 |
| type 허용값 | **Error** | `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `hotfix` |
| subject 길이 | **Error** | 50자 이내 (type, scope, 이슈번호 제외) |
| body 줄 길이 | **Warning** | 72자 초과 시 경고 (URL, 스택트레이스 등 고려하여 커밋은 진행) |

#### 출력 예시

```
[ERROR] 커밋 메시지 형식이 올바르지 않습니다.

  올바른 형식:
    <type>(<scope>): <subject> (#이슈번호)
    <type>(<scope>): <subject> (no-issue)

  허용 type: feat|fix|docs|style|refactor|test|chore|hotfix

  예시:
    feat(auth): add JWT refresh token logic (#12)
    fix(api): handle null response from external service (no-issue)
```

<br/>

## 3️⃣ pre-push — 원격 상태 확인 및 보호

push 전에 원격 브랜치 정보를 최신화하고, 로컬과 원격이 어긋나 있으면 push를 중단한다.

#### 검증 항목

| 항목 | 수준 | 설명 |
|------|------|------|
| 원격 최신화 | 자동 | `git remote update --prune` 실행 |
| diverge 감지 | **Error** | 원격에 로컬에 없는 커밋이 있으면 push 중단, pull 유도 |
| main/master 보호 | **Error** | main/master 브랜치에 직접 push 차단 |

#### 방지하는 시나리오

```
A: feature-x 브랜치에서 작업 중
B: 같은 브랜치에 커밋 후 push 완료
A: remote update 안 하고 "내가 최신" 착각 → push 시도
   → [ERROR] 원격 브랜치에 로컬에 없는 커밋이 2개 있습니다.
   → 먼저 pull 받은 후 다시 push 해주세요.
```

#### 출력 예시

```
[pre-push] 원격 브랜치 정보 동기화 중...

[ERROR] 원격 브랜치에 로컬에 없는 커밋이 2개 있습니다.

  원격: origin/feature-x
  로컬에 없는 커밋:
    a1b2c3d fix(api): handle timeout error (#45)
    d4e5f6g feat(api): add retry logic (#46)

  먼저 pull 받은 후 다시 push 해주세요:
    git pull --rebase origin feature-x
```

<br/>

## 🎯 Hook 실행 순서

수동 커밋 → push 시 Hook이 실행되는 전체 흐름:

```
git commit
  ├─ pre-commit    민감 파일? 충돌 마커? 대용량? 디버그 코드?
  └─ commit-msg    포맷 맞는가? type 유효한가? 길이 초과?

git push
  └─ pre-push      remote update → diverge 감지 → main 보호
```

> Error가 하나라도 있으면 해당 단계에서 중단된다. Warning은 경고만 출력하고 진행한다.

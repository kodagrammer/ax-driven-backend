# Agents & Schemas 가이드

역할 기반 subagent 프롬프트와 JSON Schema 계약에 대한 설계 가이드.

<br/>

## Agents (`agents/`)

`prompts/`가 **작업 단위**(커밋, 리뷰, 브랜치)의 프롬프트를 담는다면,
`agents/`는 **역할 단위**(보안 리뷰어, 테스트 분석가, 아키텍트)의 페르소나 프롬프트를 담는다.

### 파일

| 파일 | 역할 |
|------|------|
| `security-reviewer.md` | 보안 취약점 중심 리뷰어 |
| `test-reviewer.md` | 테스트 커버리지 분석가 |
| `architecture-reviewer.md` | 아키텍처 의사결정 리뷰어 |
| `review-collector.md` | base + subagent 결과 취합 전용 |

### 실행 흐름

```
ai-review
  ↓
triage → Decision JSON {review_mode, subagents[]}
  ↓
base review: review-fast.md 또는 review-deep.md (항상 실행)
  ↓
subagent dispatch (subagents[]가 있을 때):
  ├─ _ax_dispatch "security"     → tmp/review-security.md
  ├─ _ax_dispatch "test"         → tmp/review-test.md
  └─ _ax_dispatch "architecture" → tmp/review-architecture.md
  ↓
collect (결과 2개 이상):
  review-collector.md → 통합 리포트 → tmp/review.md
```

### Provider 중립 구조

| 레이어 | 역할 | 파일 |
|--------|------|------|
| Shell orchestrator | WHAT: 어떤 subagent를 실행할지 결정 | `scripts/commands/ai-review.sh` |
| Interface | 인터페이스 정의 (`_ax_dispatch`) | `scripts/lib/ai.sh` |
| Provider | HOW: provider별 실행 방식 구현 | `providers/claude.sh` |

Claude provider는 `name → md 파일 로드 → {{DIFF}} 치환 → claude --print`로 구현한다.
다른 provider(예: Codex)는 같은 `_ax_provider_dispatch` 인터페이스를 자체 방식으로 구현하면 된다.

### 프롬프트 구조 규칙

각 agent 프롬프트는 아래 구조를 따른다:

```markdown
# Input
<DIFF>
{{DIFF}}
</DIFF>

# Role / # Goal / # Review Scope / # Do NOT
# Output Format (Markdown)
# Verdict Rules
# Constraints
```

- `{{DIFF}}`: provider가 실제 diff로 치환하는 placeholder
- Constraints에 출력 언어(Korean)와 분량 제한(500 words)을 명시

<br/>

## Schemas (`schemas/`)

AI 출력물의 JSON Schema 계약 디렉토리.
AI 응답을 자연어 파싱이 아닌 **구조화된 JSON**으로 받아
셸 스크립트에서 안전하게 분기 처리하기 위한 스키마 정의.

### 파일

| 파일 | 용도 |
|------|------|
| `review-decision.schema.json` | 리뷰 triage Decision (risk_level, review_mode, subagents 등) |

### 설계 원칙

1. AI 출력에 분기 로직이 필요하면 반드시 스키마를 정의한다.
2. 스키마는 JSON Schema Draft 2020-12를 따른다.
3. 각 스키마에는 `$id`, `description`을 포함한다.

### review-decision.schema.json 주요 필드

| 필드 | 타입 | 설명 |
|------|------|------|
| `risk_level` | enum | none / low / medium / high |
| `review_mode` | enum | skip / fast / deep |
| `has_must_fix` | boolean | merge 전 필수 수정 여부 |
| `subagents` | array | 추가 실행할 전문 리뷰어 (security, test, architecture) |
| `categories` | array | 변경 카테고리 분류 |
| `confidence` | enum | triage 자체 신뢰도 (low / medium / high) |

# Project Status

**프로젝트 상태:** 실험 종료 / 가설 검증 완료
**종료 일자:** 2026-05-21

ax-driven은 “AI-assisted development workflow를 일반화한 CLI 제품”이 아니라,
**AI-assisted development에서 인간이 어디에 개입하고, AI 실행을 어떻게 제한·검증·분기할 것인가**를 코드와 문서로 탐구한 **orchestration experiment**다.
이 문서는 실험 종료 시점의 상태와, 이후의 활용·확장 의도를 한 곳에 정리한다.

<br/>

## 1. 가설 (Hypotheses)

이 레포는 다음 가설들을 CLI 파이프라인 형태로 구현해 검증했다.

- **AI workflow orchestration:** AI 호출을 단일 호출이 아니라 단계(triage → 본 리뷰 → 전문 리뷰어 fan-out → 통합)로 쪼개면, 비용·정밀도·인간 검토 부담을 균형있게 다룰 수 있다.
- **Human-in-the-loop:** 생성은 자동으로, 실행은 사람이. 되돌리기 어려운 작업(커밋, 이슈, PR)은 반드시 사람이 확인 후 실행한다.
- **Decision JSON contract:** AI 출력에 분기가 필요하면 자연어 파싱이 아니라 **JSON Schema 계약**으로 받아 셸 스크립트가 안전하게 분기한다.
- **Selective review routing:** 모든 PR에 동일한 리뷰를 돌리지 않는다. triage가 위험도와 카테고리를 판정해 `skip / fast / deep` 모드와 추가 전문 리뷰어(security, test, architecture)를 선택적으로 dispatch한다.
- **Provider abstraction (얕은 수준):** AI provider 종속을 `pipeline/scripts/providers/`에 격리해 다른 provider로 갈아끼울 수 있는 인터페이스를 둔다.
- **Cost-aware execution:** 단계별로 모델 tier(haiku / sonnet / opus)를 명시적으로 분리한다.
- **Verification-first workflow:** AI 응답이 스키마에 어긋나면 재호출이 아니라 fallback(코드 펜스 strip → JSON 블록 추출 → skip)로 비용을 우선 보호한다.

<br/>

## 2. 검증된 것 (What works today)

| 영역 | 구현 | 참조 |
|---|---|---|
| Triage → Decision JSON → conditional routing | triage 결과(JSON)에 따라 `skip / fast / deep` 모드와 subagents를 선택 dispatch | `pipeline/scripts/commands/ai-review.sh` |
| Schema 계약 + 응답 무결성 처리 | JSON Schema 검증 실패 시 코드 펜스 strip → JSON 블록 추출 fallback (재호출 없음) | `pipeline/schemas/review-decision.schema.json`, `ai-review.sh` |
| Multi-agent fan-out (최소 동작) | architecture / security / test reviewer + collector. 단발 `claude --print` 호출의 fan-out 구조 | `pipeline/agents/` |
| Provider 격리 | Claude provider는 1파일에 캡슐화, 나머지 스크립트는 provider에 의존하지 않음 | `pipeline/scripts/providers/claude.sh` |
| 모델 tier 분리 | `ai-branch`(haiku) / `ai-commit`(sonnet) / `ai-review`(opus, subagent별 tier 가능) | `bin/ax-driven.sh`, `pipeline/scripts/commands/` |
| 이슈 라벨 매핑의 JSON화 | 셸-내 매핑을 단일 JSON으로 통일 | `pipeline/schemas/issue-labels.json` |
| Git Hooks · Claude Code Hooks | 커밋 컨벤션 검증, 민감 파일 차단, lint 자동화 (선택 설치) | `hooks/git/`, `hooks/claude/` |

<br/>

## 3. 한계 (Known limits)

이 실험은 다음 지점에서 의도적으로 멈춘다. 그 너머는 IDE 통합형 AI 도구가 더 잘 풀 수 있는 영역이다.

- **유통 모델.** `git subtree`로 프로젝트마다 복제하는 방식이라 업스트림 변경 전파가 무겁다. IDE 통합형 도구(Claude Code · Cursor · Codex · Cline · Roo Code 등) 대비 채택 장벽이 높다.
- **Agent 실행 환경.** 모든 subagent가 결국 `claude --print` 단발 호출이다. 진짜 agent loop · 세션 상태 · 멀티턴 tool use는 없다. retrieval은 “diff + 변경 파일 일부 인라인” 수준에서 멈춘다.
- **Provider 추상화.** 인터페이스가 stdin/stdout 텍스트라 모델별 reasoning · tool use · streaming 등 고유 능력을 살릴 수 없다. 다른 provider를 추가하려면 인터페이스 자체를 다시 설계해야 한다.
- **사용자 베이스.** “터미널 중심 시니어 백엔드 엔지니어” 타깃이 좁다. 같은 사용자조차 빠르게 IDE 내장 agent로 이동 중이다.
- **운영 비용 곡선.** triage → fast/deep → fan-out 구조는 비용 관리 가능하나, 정밀도(예: false-critical 제거)를 끌어올릴수록 retrieval · 검증 단계가 누적되어 ROI가 급격히 떨어진다.
- **multi-agent의 한계.** 현재 fan-out은 “4개 reviewer를 순차 실행 후 collector가 마크다운 통합”에 가깝다. agent 간 협업·합의·중재 같은 진짜 multi-agent 동학은 없다.

<br/>

## 4. 종료 후 활용 방식

이 레포는 다음 두 MVP를 끝으로 더 이상 신규 기능을 추가하지 않는다. 두 MVP는 본인이 실제 활용할 베이스로만 유지된다.

- **#30 MVP — ai-review false-critical 완화.**
  - 변경 파일 full content 자동 인라인 (cap 5 files / 30k chars)
  - `pipeline/prompts/review-deep.md` · `review-fast.md`에 “미확인 시 단정 금지, evidence 없는 critical은 강등” 가이드 2문장
  - 후처리: `critical`인데 evidence(파일/심볼/라인) 비어있으면 `warning`으로 자동 강등
- **#11 MVP — 프롬프트 구조 린트 CI.**
  - `tests/lint-prompts.sh` 한 파일로 prompts/agents/templates 필수 섹션 헤딩 존재 여부만 검증
  - `.github/workflows/prompt-lint.yml`이 해당 경로 변경 시 실행

신규 기능 추가, 신규 agent · provider · 명령어 추가, 신규 schema 신설은 없다.

<br/>

## 5. Future direction (out of scope)

다음 항목들은 명시적으로 **이 레포의 범위 밖**으로 둔다. 필요해지면 별도 레포 또는 IDE 통합형 도구로 이관한다.

- autonomous coding agent화, IDE 수준의 통합 개발 환경 구현
- full agent loop, 장기 메모리 시스템
- multi-agent platform화 (agent 간 협업/중재/합의)
- 깊은 provider abstraction (Codex / Gemini 등 신규 provider, tool use·streaming 활용)
- CLI SaaS화, 제품 수준의 배포·과금 모델
- 사내 문서 RAG CLI (구 issue #12) — IDE 도구로 대체 가능
- ai-review v2 — Phase 2 retrieval(import/symbol depth), severity gating 매트릭스, JSON→마크다운 렌더러 분리, 4 subagent JSON 정합 재설계, 신규 schema 2종 신설 (구 issue #30의 잔여 Task 1·2·3·6·8·9·10)
- 프롬프트 품질 CI 확장 — 파일명 넘버링 연속성, PR 코멘트 액션, SARIF 업로드 등 (구 issue #11의 잔여 항목)
- 백엔드 업무 자동화(엣지케이스 자동 추출 → JUnit/통합테스트 생성 등) — 별도 레포로 분리 권장

<br/>

## 6. 결론

이 프로젝트는 **“제품 완성”이 아니라 “가설 검증 완료”** 를 마무리 기준으로 한다.
실험 결과는 코드(`pipeline/`)와 가이드(`docs/guides/`)에 남는다.
이후의 운영·확장은 본인의 다른 프로젝트나 IDE 통합형 AI 도구로 옮겨간다.

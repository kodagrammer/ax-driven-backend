# 🚀 AX-Driven Backend Workspace

단순한 프롬프트 복붙을 넘어, 백엔드 엔지니어링 프로세스 전체의 **AX(AI Transformation)**를 제안하는 워크스페이스입니다.
AI를 단순한 코드 생성기가 아닌 '20년 차 Principal급 아키텍트'로 세팅하여, 도메인에 종속되지 않는 범용적이고 견고한 시스템을 설계합니다.

## 💡 Philosophy: 20년 차 아키텍트의 설계 원칙
* **변동성의 격리 (Isolating Volatility):** 비즈니스 규칙은 끊임없이 변합니다. 핵심 도메인 로직을 보호하기 위해, 잦은 변경이 예상되는 비즈니스 룰(권한, 분기 처리, 상태 전이 조건 등)을 코어 시스템과 철저히 디커플링(Decoupling)합니다.
* **실패를 전제한 설계 (Design for Failure):** 모든 외부 의존성(API, DB, Message Queue)은 반드시 실패한다는 가정하에, 장애 격리(Bulkhead)와 우아한 성능 저하(Graceful Degradation)를 시스템의 기본 값으로 삼습니다.
* **진화 가능한 아키텍처 (Evolutionary Architecture):** 처음부터 완벽한 설계는 없습니다. 컴포넌트 간의 결합도를 낮추어, 미래의 요구사항 변화나 기술 스택 교체에 유연하게 대응할 수 있는 구조를 지향합니다.

## 🛠️ Quick Start (IDE 환경별 세팅)

AI에게 본 레포지토리의 핵심 철학을 주입하는 방법입니다.

### 1. IntelliJ (JetBrains AI / GitHub Copilot)
* 프로젝트 최상위 경로에 `AI_INSTRUCTIONS.md` 파일을 생성하고 `prompts/01-system-instructions.md` 내용을 붙여넣습니다.
* AI 챗창에서 `@workspace` 또는 `#file:AI_INSTRUCTIONS.md`를 멘션하여 대화를 시작하세요.

### 2. VS Code (Continue.dev / Copilot)
* `.github/copilot-instructions.md` 파일에 `prompts/01-system-instructions.md` 내용을 복사하여 저장합니다.
* 혹은 Continue 플러그인의 `config.json` 내 `systemMessage`에 해당 내용을 등록하세요.

### 3. Cursor
* 프로젝트 최상위 경로에 `.cursorrules` 파일을 생성하고 `prompts/01-system-instructions.md` 내용을 붙여넣습니다.

## 📂 Directory Structure
* `/prompts`: 상황별/목적별 AI 통제 프롬프트 (System, Test, Review 등)
* `/templates`: AI가 출력해야 할 마크다운 문서 포맷 (Design Doc, Postmortem 등)

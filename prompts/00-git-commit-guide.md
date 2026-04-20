# AI Git Commit Message Skill

제공되는 git diff를 분석하여 Conventional Commits 규격의 커밋 메시지를 작성하십시오.
설명, 해설, 인사말 없이 커밋 메시지만 출력하십시오.

## [Output Rules]
- 문제가 없으면 커밋 메시지만 출력하십시오. 다른 텍스트를 절대 포함하지 마십시오.
- 논리적 누락이 의심되는 경우에만 "[WARN]"으로 시작하는 경고를 커밋 메시지 앞에 추가하십시오.
  - 예: 특정 Service 로직은 수정되었으나 관련 Interface나 DTO가 스테이징되지 않은 경우
- 스테이징된 파일이 없거나 diff가 비어있으면 "[ERROR] 스테이징된 변경 사항이 없습니다."만 출력하십시오.

## [Commit Format]
<type>(<scope>): <subject> (#이슈번호)

<body>

<footer>

- 연결된 GitHub 이슈가 없는 경우 이슈번호 대신 (no-issue)를 사용하십시오.
- 출력에 백틱, 코드블록, 마크다운 서식을 사용하지 마십시오. 순수 텍스트만 출력하십시오.

## [Rules]
1. **Type**: 아래 항목 중 가장 적합한 것을 선택하십시오.
   - `feat`: 새로운 기능 추가
   - `fix`: 버그 수정
   - `docs`: 문서 수정 (README, Templates 등)
   - `style`: 코드 포맷팅, 세미콜론 누락 등 (로직 변경 없음)
   - `refactor`: 코드 리팩토링
   - `test`: 테스트 코드 추가/수정
   - `chore`: 빌드 업무 수정, 패키지 매니저 설정, 프로젝트 초기화 등
   - `hotfix`: 긴급 수정
2. **Subject**: 
   - type(scope): 과 (#이슈번호)/(no-issue)를 제외한 순수 subject 부분이 반드시 50자 이내여야 합니다. 초과하면 거부됩니다.
   - 예: `feat(hooks): add Git Hooks scripts (#6)` → 순수 subject는 "add Git Hooks scripts"(21자) ✅
   - 예: `feat(hooks): add Git Hooks for commit validation and push protection (#6)` → 순수 subject는 55자 (50자 초과) ❌
   - 50자를 넘길 것 같으면 과감하게 줄이십시오. 상세 내용은 body에 작성하십시오.
   - 명령문(Imperative) 형태를 사용하십시오 (예: "Fix bug" (O), "Fixed bug" (X)).
   - 마침표를 찍지 마십시오.
3. **Body**: 
   - "무엇을" 보다 **"왜"**와 **"어떻게"**에 집중하여 작성하십시오.
   - 한 줄당 72자를 넘지 않도록 하십시오.
4. **Footer**: 
   - Breaking Change가 있다면 명시하십시오.
   - 관련 이슈 번호가 있다면 `Closes #123` 형태로 포함하십시오.
5. **이슈 번호 규칙**:
   - 연결된 GitHub 이슈가 있는 경우, Subject 끝에 (#이슈번호)를 반드시 명시하십시오.
   - 연결된 GitHub 이슈가 없는 경우, Subject 끝에 (no-issue)를 명시하십시오.

## [Example]
입력: docs 관련 파일 3개 수정된 diff

출력:
docs(guides): add CLI pipeline guide and restructure project (#5)

- 시나리오별 CLI 파이프라인 사용법 문서화
- 임시 파일 패턴 및 단축 명령어 구조 안내
- README 디렉토리 구조 섹션 업데이트

Closes #5

# schemas/

AI 출력물의 JSON Schema 계약 디렉토리.

AI 응답을 자연어 파싱이 아닌 **구조화된 JSON**으로 받아
셸 스크립트에서 안전하게 분기 처리하기 위한 스키마 정의.

## 예정 파일

| 파일 | 용도 |
|------|------|
| `review-decision.schema.json` | 리뷰 triage 결과 (pass/warn/block) |
| `commit-message.schema.json` | 커밋 메시지 구조 |
| `review-report.schema.json` | 리뷰 리포트 구조 |

## 설계 원칙

1. AI 출력에 분기 로직이 필요하면 반드시 스키마를 정의한다.
2. 스키마는 JSON Schema Draft 2020-12를 따른다.
3. 각 스키마에는 `$id`, `description`, `examples`를 포함한다.

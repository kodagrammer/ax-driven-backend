#!/bin/bash
# _ai-review.sh — PR 아키텍처 리뷰 (orchestration-first)
# ax-driven.sh에서 source됨. 직접 실행하지 않는다.
#
# 흐름: diff 수집 → triage → JSON 검증 → 실행 계획 출력 → review_mode 분기
# --json 옵션: triage Decision JSON만 출력하고 종료

# triage 실행: diff를 분류하여 Decision JSON 반환
# 사용법: _ax_review_triage <ax_root> <base>
# stdout: triage JSON, stderr: 에러/토큰 로그
_ax_review_triage() {
  local _rt_root="$1"
  local _rt_base="$2"
  local _rt_tmp="${_rt_root}/tmp"
  local _rt_json _rt_rc

  _AX_TOKEN_FILE="$_rt_tmp/triage-token.log"
  export _AX_TOKEN_FILE
  _rt_json=$({ cat "${_rt_root}/prompts/review-triage.md"; echo; echo "## Changed Files"; git diff "$_rt_base...HEAD" --stat; echo; echo "## Diff Headers"; git diff "$_rt_base...HEAD" | grep -E '^(diff --git|@@|[+-]{3} )'; } \
    | _ax_ai low 2>"$_rt_tmp/triage-error.log")
  _rt_rc=$?
  unset _AX_TOKEN_FILE

  if [ $_rt_rc -ne 0 ] || [ -z "$_rt_json" ]; then
    if [ -s "$_rt_tmp/triage-error.log" ]; then
      echo "[ERROR] triage 요청 실패:" >&2
      cat "$_rt_tmp/triage-error.log" >&2
    else
      echo "[ERROR] triage 응답이 비어있습니다." >&2
    fi
    rm -f "$_rt_tmp/triage-token.log" "$_rt_tmp/triage-error.log"
    return 1
  fi
  rm -f "$_rt_tmp/triage-error.log"

  if [ -s "$_rt_tmp/triage-token.log" ]; then
    cat "$_rt_tmp/triage-token.log" >&2
    rm -f "$_rt_tmp/triage-token.log"
  fi

  # 마크다운 코드 펜스 strip (모델이 ```json ... ``` 로 감쌀 경우 방어)
  _rt_json=$(printf '%s\n' "$_rt_json" | sed '/^```/d')

  printf '%s\n' "$_rt_json"
}

# jq 필수 의존성 확인
_ax_require_jq_for_review() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "[ERROR] jq is required for ai-review triage." >&2
    echo "  Install jq and try again." >&2
    return 1
  fi
}

# jq 기반 JSON 검증
# 사용법: echo "$json" | _ax_review_validate
# 종료코드: 0=유효, 1=무효 (stderr에 사유 출력)
_ax_review_validate() {
  local _rv_json _rv_err
  _rv_json=$(cat)

  # JSON 파싱 가능한지
  if ! printf '%s\n' "$_rv_json" | jq empty 2>/dev/null; then
    echo "[ERROR] triage 응답이 유효한 JSON이 아닙니다." >&2
    printf '%s\n' "$_rv_json" >&2
    return 1
  fi

  # 필수 필드 존재 + enum 검증
  _rv_err=$(printf '%s\n' "$_rv_json" | jq -r '
    def check:
      (if .risk_level then null else "risk_level 누락" end),
      (if .review_mode then null else "review_mode 누락" end),
      (if (.has_must_fix | type) == "boolean" then null else "has_must_fix는 boolean이어야 합니다" end),
      (if .risk_level and (.risk_level | IN("none","low","medium","high")) then null else "risk_level 값 오류: \(.risk_level)" end),
      (if .review_mode and (.review_mode | IN("skip","fast","deep")) then null else "review_mode 값 오류: \(.review_mode)" end),
      (if .confidence and (.confidence | IN("low","medium","high")) then null else "confidence 값 오류: \(.confidence)" end);
    [check] | map(select(. != null)) | if length > 0 then join("; ") else empty end
  ' 2>/dev/null)

  if [ -n "$_rv_err" ]; then
    echo "[ERROR] triage JSON 검증 실패: $_rv_err" >&2
    return 1
  fi

  printf '%s\n' "$_rv_json"
}

# 실행 계획 마크다운 출력
# 사용법: echo "$json" | _ax_review_plan <action_label>
_ax_review_plan() {
  local _rp_action="$1"
  local _rp_json _rp_risk _rp_mode _rp_must _rp_subs _rp_conf _rp_cats _rp_reason
  _rp_json=$(cat)

  _rp_risk=$(printf '%s\n' "$_rp_json" | jq -r '.risk_level')
  _rp_mode=$(printf '%s\n' "$_rp_json" | jq -r '.review_mode')
  _rp_must=$(printf '%s\n' "$_rp_json" | jq -r 'if .has_must_fix then "yes" else "no" end')
  _rp_subs=$(printf '%s\n' "$_rp_json" | jq -r '(.subagents // []) | if length > 0 then join(", ") else "none" end')
  _rp_conf=$(printf '%s\n' "$_rp_json" | jq -r '.confidence')
  _rp_cats=$(printf '%s\n' "$_rp_json" | jq -r '(.categories // []) | if length > 0 then join(", ") else "none" end')
  _rp_reason=$(printf '%s\n' "$_rp_json" | jq -r '.reason // "N/A"')

  echo ""
  echo "# AI Review Plan"
  echo ""
  echo "## Decision"
  echo "- Risk Level: $_rp_risk"
  echo "- Review Mode: $_rp_mode"
  echo "- Must Fix: $_rp_must"
  echo "- Subagents: $_rp_subs"
  echo "- Categories: $_rp_cats"
  echo "- Confidence: $_rp_conf"
  echo ""
  echo "## Reason"
  echo "$_rp_reason"
  echo ""
  echo "## Execution"
  echo "$_rp_action"
  echo ""
}

# 기존 리뷰 실행 (tier 파라미터화)
# 사용법: _ax_review_exec <ax_root> <base> <tier>
_ax_review_exec() {
  local _re_root="$1"
  local _re_base="$2"
  local _re_tier="$3"
  local _re_tmp="${_re_root}/tmp"
  local _re_file="$_re_tmp/review.md"
  local _re_rc

  echo "[ax-driven] AI 리뷰 생성 중... (tier: $_re_tier)"
  _AX_TOKEN_FILE="$_re_tmp/token.log"
  export _AX_TOKEN_FILE
  { cat "${_re_root}/prompts/03-pr-reviewer.md"; git diff "$_re_base...HEAD"; } \
    | _ax_ai "$_re_tier" 300 > "$_re_file" 2>"$_re_tmp/error.log"
  _re_rc=$?
  unset _AX_TOKEN_FILE

  if [ $_re_rc -ne 0 ] || [ ! -s "$_re_file" ]; then
    if [ -s "$_re_tmp/error.log" ]; then
      echo "[ERROR] AI 요청 실패:" >&2
      cat "$_re_tmp/error.log" >&2
    else
      echo "[ERROR] AI 응답이 비어있습니다." >&2
    fi
    rm -f "$_re_file" "$_re_tmp/token.log"
    return 1
  fi
  rm -f "$_re_tmp/error.log"

  echo "[ax-driven] 생성 완료: $_re_file"
  if [ -s "$_re_tmp/token.log" ]; then
    cat "$_re_tmp/token.log"
    rm -f "$_re_tmp/token.log"
  fi
  echo ""

  ${EDITOR:-vi} "$_re_file"
}

# review_mode + risk_level → 리뷰 tier 결정
# 사용법: _ax_review_tier <review_mode> <risk_level>
_ax_review_tier() {
  case "$1" in
    fast) echo "low" ;;
    deep)
      case "$2" in
        high) echo "high" ;;
        *)    echo "standard" ;;
      esac
      ;;
    *) echo "none" ;;
  esac
}

ai-review() {
  local _ax_root="$_AX_ROOT"
  local _tmp="${_ax_root}/tmp"
  local _json_mode=false
  local _base _review_file _triage_json _triage_failed
  local _review_mode _risk_level _tier

  # --- 인자 파싱 ---
  _base=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --json)
        _json_mode=true
        ;;
      --*)
        echo "[Error] 알 수 없는 옵션: $1" >&2
        return 1
        ;;
      *)
        if [ -z "$_base" ]; then
          _base="$1"
        else
          echo "[Error] 인자가 너무 많습니다: $1" >&2
          return 1
        fi
        ;;
    esac
    shift
  done
  _base="${_base:-main}"
  _review_file="$_tmp/review.md"

  # _base 입력값 검증 (명령 주입 방지 — 브랜치명 허용 문자만 통과)
  case "$_base" in
    *[!a-zA-Z0-9/_.-]*)
      echo "[Error] 유효하지 않은 브랜치명입니다: $_base" >&2
      return 1 ;;
  esac

  # diff 확인
  if [ -z "$(git diff "${_base}...HEAD" --name-only)" ]; then
    echo "[ERROR] ${_base} 브랜치 대비 변경 사항이 없습니다." >&2
    return 1
  fi

  # 임시 파일 안전장치 (--json 모드에서는 리뷰 파일을 쓰지 않으므로 건너뜀)
  if [ "$_json_mode" = false ] && [ -f "$_review_file" ]; then
    echo "" >&2
    echo "[WARN] 작업중이던 항목이 있습니다: $_review_file" >&2
    echo "  확인: \${EDITOR:-vi} $_review_file" >&2
    echo "  정리: _ax_done review" >&2
    echo "" >&2
    return 1
  fi

  mkdir -p "$_tmp"

  # jq 필수 확인
  _ax_require_jq_for_review || return 1

  # --- triage ---
  echo "[ax-driven] triage 분석 중..." >&2
  _triage_failed=false
  _triage_json=$(_ax_review_triage "$_ax_root" "$_base")
  if [ $? -ne 0 ]; then
    _triage_failed=true
  fi

  # JSON 검증
  if [ "$_triage_failed" = false ]; then
    _triage_json=$(printf '%s\n' "$_triage_json" | _ax_review_validate)
    if [ $? -ne 0 ]; then
      _triage_failed=true
    fi
  fi

  # triage 실패 시 fallback: skip (리뷰 실행하지 않음)
  if [ "$_triage_failed" = true ]; then
    echo "[WARN] triage 실패 — fallback: skip. 리뷰를 건너뜁니다." >&2
    echo "  수동 리뷰가 필요하면 diff를 직접 확인하세요: git diff ${_base}...HEAD" >&2
    return 1
  fi

  # --json 모드: Decision JSON만 출력하고 종료
  if [ "$_json_mode" = true ]; then
    printf '%s\n' "$_triage_json" | jq .
    return 0
  fi

  # --- routing ---
  _review_mode=$(printf '%s\n' "$_triage_json" | jq -r '.review_mode')
  _risk_level=$(printf '%s\n' "$_triage_json" | jq -r '.risk_level')
  _tier=$(_ax_review_tier "$_review_mode" "$_risk_level")

  # skip → 실행 계획만 출력하고 종료
  if [ "$_review_mode" = "skip" ]; then
    printf '%s\n' "$_triage_json" | _ax_review_plan "Skip — 리뷰가 필요하지 않습니다."
    return 0
  fi

  # fast/deep → 실행 계획 출력 후 리뷰 실행
  printf '%s\n' "$_triage_json" | _ax_review_plan "Running ${_review_mode} review... (tier: $_tier)"
  echo ""
  echo "  편집기에서 리뷰 결과를 확인해주세요."
  echo "  리뷰 반영 후 _ax_done review 로 정리해주세요."
  echo ""
  _ax_review_exec "$_ax_root" "$_base" "$_tier"
}

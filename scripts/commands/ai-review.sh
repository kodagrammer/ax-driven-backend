#!/bin/bash
# _ai-review.sh — PR 아키텍처 리뷰 (orchestration-first)
# ax-driven.sh에서 source됨. 직접 실행하지 않는다.
#
# 흐름: diff mode 선택 → diff 수집 → triage → JSON 검증 → 실행 계획 출력 → review_mode 분기
# diff modes: staged (default), --all, --branch [base]
# --json 옵션: triage Decision JSON만 출력하고 종료

# diff mode별 git diff 실행
# 사용법: _ax_review_diff <mode> <base> [extra args...]
# mode: staged | all | branch
_ax_review_diff() {
  local _rd_mode="$1" _rd_base="$2"
  shift 2
  case "$_rd_mode" in
    all)    git diff HEAD "$@" ;;
    branch) git diff "${_rd_base}...HEAD" "$@" ;;
    *)      git diff --cached "$@" ;;
  esac
}

# help 출력
_ax_review_help() {
  cat <<'HELP'
Usage:
  ai-review [options]

Options:
  --all
    Review all local changes (staged + unstaged)

  --branch [base]
    Review branch diff against base (default: main)

  --json
    Output triage Decision JSON only

  --help, -h
    Show this help message

Description:
  Default behavior reviews staged changes only.

Examples:
  ai-review
  ai-review --all
  ai-review --branch
  ai-review --branch develop
HELP
}

# triage 실행: diff를 분류하여 Decision JSON 반환
# 사용법: _ax_review_triage <ax_root> <mode> <base>
# stdout: triage JSON, stderr: 에러/토큰 로그
_ax_review_triage() {
  local _rt_root="$1"
  local _rt_mode="$2"
  local _rt_base="$3"
  local _rt_tmp="${_rt_root}/tmp"
  local _rt_json _rt_rc

  _AX_TOKEN_FILE="$_rt_tmp/triage-token.log"
  export _AX_TOKEN_FILE
  _rt_json=$({ cat "${_rt_root}/prompts/review-triage.md"; echo; echo "## Changed Files"; _ax_review_diff "$_rt_mode" "$_rt_base" --stat; echo; echo "## Diff Headers"; _ax_review_diff "$_rt_mode" "$_rt_base" | grep -E '^(diff --git|@@|[+-]{3} )'; } \
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
# 사용법: echo "$execution_plan_json" | _ax_review_plan <action_label>
_ax_review_plan() {
  local _rp_action="$1"
  local _rp_json
  _rp_json=$(cat)

  local _rp_risk _rp_mode _rp_eff _rp_tier _rp_must _rp_subs _rp_conf _rp_preason _rp_reason
  _rp_risk=$(printf '%s\n' "$_rp_json" | jq -r '.risk_level')
  _rp_mode=$(printf '%s\n' "$_rp_json" | jq -r '.review_mode')
  _rp_eff=$(printf '%s\n' "$_rp_json" | jq -r '.effective_review_mode')
  _rp_tier=$(printf '%s\n' "$_rp_json" | jq -r '.tier')
  _rp_must=$(printf '%s\n' "$_rp_json" | jq -r 'if .has_must_fix then "yes" else "no" end')
  _rp_subs=$(printf '%s\n' "$_rp_json" | jq -r '(.subagents // []) | if length > 0 then join(", ") else "none" end')
  _rp_conf=$(printf '%s\n' "$_rp_json" | jq -r '.confidence')
  _rp_preason=$(printf '%s\n' "$_rp_json" | jq -r '.promotion_reason // ""')
  _rp_reason=$(printf '%s\n' "$_rp_json" | jq -r '.reason // "N/A"')

  echo ""
  echo "# AI Review Plan"
  echo ""
  echo "## Decision"
  echo "- Risk Level: $_rp_risk"
  echo "- Review Mode: $_rp_mode"
  echo "- Effective Review Mode: $_rp_eff"
  echo "- Tier: $_rp_tier"
  echo "- Must Fix: $_rp_must"
  echo "- Planned Specialized Checks: $_rp_subs"
  echo "- Confidence: $_rp_conf"
  if [ -n "$_rp_preason" ]; then
    echo "- Promotion Reason: $_rp_preason"
  fi
  echo ""
  echo "## Reason"
  echo "$_rp_reason"
  echo ""
  echo "## Execution"
  echo "$_rp_action"
  echo ""
}

# prompt 선택: review_mode → prompt 파일 경로
# 사용법: _ax_review_prompt <ax_root> <effective_review_mode>
_ax_review_prompt() {
  local _rpr_root="$1" _rpr_mode="$2"
  case "$_rpr_mode" in
    fast) echo "${_rpr_root}/prompts/review-fast.md" ;;
    deep) echo "${_rpr_root}/prompts/review-deep.md" ;;
    *)    echo "[ERROR] unknown review mode: $_rpr_mode" >&2; return 1 ;;
  esac
}

# 리뷰 실행 (tier + prompt 파라미터화)
# 사용법: _ax_review_exec <ax_root> <mode> <base> <tier> <effective_review_mode>
_ax_review_exec() {
  local _re_root="$1"
  local _re_mode="$2"
  local _re_base="$3"
  local _re_tier="$4"
  local _re_eff="$5"
  local _re_tmp="${_re_root}/tmp"
  local _re_file="$_re_tmp/review.md"
  local _re_prompt _re_rc

  _re_prompt=$(_ax_review_prompt "$_re_root" "$_re_eff")
  if [ $? -ne 0 ] || [ -z "$_re_prompt" ]; then
    echo "[ERROR] prompt 선택 실패: mode=$_re_eff" >&2
    return 1
  fi
  if [ ! -f "$_re_prompt" ]; then
    echo "[ERROR] prompt 파일 없음: $_re_prompt" >&2
    return 1
  fi

  echo "[ax-driven] AI 리뷰 생성 중... (tier: $_re_tier, prompt: $(basename "$_re_prompt"))"

  # prompt 내 {{DIFF}} placeholder를 실제 diff로 치환
  local _re_diff_file="$_re_tmp/diff.tmp"
  _ax_review_diff "$_re_mode" "$_re_base" > "$_re_diff_file"

  local _re_input
  if grep -q '{{DIFF}}' "$_re_prompt"; then
    _re_input=$(sed -e "/{{DIFF}}/r $_re_diff_file" -e '/{{DIFF}}/d' "$_re_prompt")
  else
    _re_input=$(cat "$_re_prompt"; cat "$_re_diff_file")
  fi
  rm -f "$_re_diff_file"

  _AX_TOKEN_FILE="$_re_tmp/token.log"
  export _AX_TOKEN_FILE
  printf '%s\n' "$_re_input" \
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

# triage JSON → execution plan JSON
# stdin: validated triage JSON
# stdout: execution plan JSON
_ax_review_build_execution_plan() {
  local _bp_json _bp_mode _bp_conf _bp_must _bp_risk
  local _bp_eff _bp_promoted=false _bp_reason=""
  _bp_json=$(cat)

  _bp_mode=$(printf '%s\n' "$_bp_json" | jq -r '.review_mode')
  _bp_conf=$(printf '%s\n' "$_bp_json" | jq -r '.confidence')
  _bp_must=$(printf '%s\n' "$_bp_json" | jq -r '.has_must_fix')
  _bp_risk=$(printf '%s\n' "$_bp_json" | jq -r '.risk_level')

  # promotion 로직 (skip/deep은 대상 아님)
  _bp_eff="$_bp_mode"
  if [ "$_bp_mode" != "skip" ] && [ "$_bp_mode" != "deep" ]; then
    if [ "$_bp_must" = "true" ]; then
      _bp_reason="must-fix risk detected"
    fi
    if [ "$_bp_conf" = "low" ]; then
      _bp_reason="${_bp_reason:+${_bp_reason}; }confidence is low"
    fi
    if [ -n "$_bp_reason" ]; then
      _bp_eff="deep"
      _bp_promoted=true
    fi
  fi

  # tier 결정
  local _bp_tier="none"
  case "$_bp_eff" in
    fast) _bp_tier="low" ;;
    deep)
      case "$_bp_risk" in
        high) _bp_tier="high" ;;
        *)    _bp_tier="standard" ;;
      esac
      ;;
  esac

  # execution plan JSON 생성
  printf '%s\n' "$_bp_json" | jq \
    --arg eff "$_bp_eff" \
    --arg tier "$_bp_tier" \
    --argjson promoted "$_bp_promoted" \
    --arg reason "$_bp_reason" \
    '. + {effective_review_mode: $eff, tier: $tier, promoted: $promoted, promotion_reason: $reason}'
}

ai-review() {
  local _ax_root="$_AX_ROOT"
  local _tmp="${_ax_root}/tmp"
  local _json_mode=false
  local _diff_mode="staged" _branch_base=""
  local _review_file _triage_json _triage_failed

  # --- 인자 파싱 ---
  while [ $# -gt 0 ]; do
    case "$1" in
      --help|-h)
        _ax_review_help
        return 0
        ;;
      --json)
        _json_mode=true
        ;;
      --all)
        if [ "$_diff_mode" != "staged" ]; then
          echo "[Error] --all과 --branch는 동시에 사용할 수 없습니다." >&2
          return 1
        fi
        _diff_mode="all"
        ;;
      --branch)
        if [ "$_diff_mode" != "staged" ]; then
          echo "[Error] --all과 --branch는 동시에 사용할 수 없습니다." >&2
          return 1
        fi
        _diff_mode="branch"
        if [ $# -gt 1 ] && case "$2" in --*) false ;; *) true ;; esac; then
          _branch_base="$2"
          shift
        fi
        ;;
      --*)
        echo "[Error] 알 수 없는 옵션: $1" >&2
        return 1
        ;;
      *)
        echo "[Error] 알 수 없는 인자: $1" >&2
        return 1
        ;;
    esac
    shift
  done

  _branch_base="${_branch_base:-main}"
  _review_file="$_tmp/review.md"

  # --branch base 입력값 검증 (명령 주입 방지)
  if [ "$_diff_mode" = "branch" ]; then
    case "$_branch_base" in
      *[!a-zA-Z0-9/_.-]*)
        echo "[Error] 유효하지 않은 브랜치명입니다: $_branch_base" >&2
        return 1 ;;
    esac
  fi

  # diff 확인 — 모드별 안내 메시지
  if [ -z "$(_ax_review_diff "$_diff_mode" "$_branch_base" --name-only)" ]; then
    case "$_diff_mode" in
      staged)
        echo "No staged changes found." >&2
        echo "Stage files first with: git add <path>" >&2
        echo "Or use --all to review unstaged changes." >&2
        ;;
      all)
        echo "No local changes found." >&2
        ;;
      branch)
        echo "No branch changes found against ${_branch_base}." >&2
        ;;
    esac
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
  _triage_json=$(_ax_review_triage "$_ax_root" "$_diff_mode" "$_branch_base")
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
    echo "  수동 리뷰가 필요하면 diff를 직접 확인하세요." >&2
    return 1
  fi

  # --json 모드: Decision JSON만 출력하고 종료
  if [ "$_json_mode" = true ]; then
    printf '%s\n' "$_triage_json" | jq .
    return 0
  fi

  # --- execution plan ---
  local _exec_plan _eff_mode _tier
  _exec_plan=$(printf '%s\n' "$_triage_json" | _ax_review_build_execution_plan)
  if [ $? -ne 0 ] || [ -z "$_exec_plan" ]; then
    echo "[ERROR] execution plan 생성 실패" >&2
    return 1
  fi
  _eff_mode=$(printf '%s\n' "$_exec_plan" | jq -r '.effective_review_mode')
  _tier=$(printf '%s\n' "$_exec_plan" | jq -r '.tier')

  # skip → report 출력 후 안내 메시지
  if [ "$_eff_mode" = "skip" ]; then
    printf '%s\n' "$_exec_plan" | _ax_review_plan "Skip"
    echo ""
    echo "No meaningful review target detected."
    echo "Review skipped."
    return 0
  fi

  # fast/deep → 실행 계획 출력 후 리뷰 실행
  printf '%s\n' "$_exec_plan" | _ax_review_plan "Running ${_eff_mode} review... (tier: $_tier)"
  echo ""
  echo "  편집기에서 리뷰 결과를 확인해주세요."
  echo "  리뷰 반영 후 _ax_done review 로 정리해주세요."
  echo ""
  _ax_review_exec "$_ax_root" "$_diff_mode" "$_branch_base" "$_tier" "$_eff_mode"
}

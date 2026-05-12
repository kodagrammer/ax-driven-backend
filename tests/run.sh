#!/bin/bash
# tests/run.sh — ax-driven 기본 smoke test
# 사용법: bash tests/run.sh

_PASS=0
_FAIL=0
_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

_check() {
  if eval "$2" >/dev/null 2>&1; then
    echo "  [PASS] $1"
    _PASS=$((_PASS + 1))
  else
    echo "  [FAIL] $1"
    _FAIL=$((_FAIL + 1))
  fi
}

echo "[ax-driven] smoke test"
echo ""

# 1. 스크립트 문법 검사
echo "## 문법 검사 (bash -n)"
_check "bin/ax-driven.sh"           "bash -n '$_ROOT/bin/ax-driven.sh'"
_check "pipeline/scripts/providers/claude.sh"        "bash -n '$_ROOT/pipeline/scripts/providers/claude.sh'"
_check "pipeline/scripts/lib/utils.sh"       "bash -n '$_ROOT/pipeline/scripts/lib/utils.sh'"
_check "pipeline/scripts/commands/ai-commit.sh"  "bash -n '$_ROOT/pipeline/scripts/commands/ai-commit.sh'"
_check "pipeline/scripts/commands/ai-branch.sh"  "bash -n '$_ROOT/pipeline/scripts/commands/ai-branch.sh'"
_check "pipeline/scripts/commands/ai-review.sh"  "bash -n '$_ROOT/pipeline/scripts/commands/ai-review.sh'"
_check "pipeline/scripts/commands/ai-issue.sh"   "bash -n '$_ROOT/pipeline/scripts/commands/ai-issue.sh'"
echo ""

# 2. 필수 디렉토리 존재
echo "## 필수 디렉토리"
_check "pipeline/prompts/ 존재"        "[ -d '$_ROOT/pipeline/prompts' ]"
_check "pipeline/scripts/providers/ 존재"  "[ -d '$_ROOT/pipeline/scripts/providers' ]"
_check "pipeline/scripts/lib/ 존재"      "[ -d '$_ROOT/pipeline/scripts/lib' ]"
_check "pipeline/scripts/commands/ 존재" "[ -d '$_ROOT/pipeline/scripts/commands' ]"
echo ""

# 필수 의존성
echo "## 필수 의존성"
_check "jq 설치" "command -v jq >/dev/null 2>&1"
echo ""

# 3. source 가능 여부
echo "## source 테스트"
_check "bin/ax-driven.sh source" "bash -c 'cd $_ROOT && source bin/ax-driven.sh && type ai-commit >/dev/null 2>&1'"
echo ""

# ai-review empty diff 가드: 빈 git repo에서 모드별 안내 메시지 확인
_check_review_empty() {
  local desc="$1" args="$2" expected="$3"
  local tmp out
  tmp=$(mktemp -d)
  out=$(
    cd "$tmp" && git init -q -b main >/dev/null 2>&1 \
      && git commit -q --allow-empty -m init >/dev/null 2>&1 \
      && source "$_ROOT/bin/ax-driven.sh" >/dev/null 2>&1 \
      && eval "ai-review $args" 2>&1
  )
  rm -rf "$tmp"
  if echo "$out" | grep -q "$expected"; then
    echo "  [PASS] $desc"
    _PASS=$((_PASS + 1))
  else
    echo "  [FAIL] $desc (expected: $expected)"
    _FAIL=$((_FAIL + 1))
  fi
}

# subagent dispatch 빈 diff 가드 검증
_check_dispatch_empty() {
  local desc="$1"
  local tmp out
  tmp=$(mktemp -d)
  out=$(
    cd "$tmp" && git init -q -b main >/dev/null 2>&1 \
      && git commit -q --allow-empty -m init >/dev/null 2>&1 \
      && source "$_ROOT/bin/ax-driven.sh" >/dev/null 2>&1 \
      && _ax_review_dispatch_subagents "$tmp" branch main low '["security"]' 2>&1
  )
  rm -rf "$tmp"
  if echo "$out" | grep -q "subagent dispatch용 diff가 비어있습니다"; then
    echo "  [PASS] $desc"
    _PASS=$((_PASS + 1))
  else
    echo "  [FAIL] $desc"
    _FAIL=$((_FAIL + 1))
  fi
}

echo "## ai-review empty diff 가드"
_check_review_empty "staged 빈 경우 안내"  ""              "No staged changes"
_check_review_empty "all 빈 경우 안내"     "--all"         "No local changes"
_check_review_empty "branch 빈 경우 안내"  "--branch main" "No branch changes"
_check_dispatch_empty "subagent dispatch 빈 diff 가드"
echo ""

# JSON 추출 헬퍼: 깨진 응답에서 JSON 블록만 복구 가능한지 검증
_check_extract() {
  local desc="$1" input="$2" expected="$3"
  local out
  out=$(
    source "$_ROOT/bin/ax-driven.sh" >/dev/null 2>&1
    printf '%s' "$input" | _ax_review_extract_json
  )
  if echo "$out" | grep -q "$expected"; then
    echo "  [PASS] $desc"
    _PASS=$((_PASS + 1))
  else
    echo "  [FAIL] $desc (got: $out)"
    _FAIL=$((_FAIL + 1))
  fi
}

_check_extract_empty() {
  local desc="$1" input="$2"
  local out
  out=$(
    source "$_ROOT/bin/ax-driven.sh" >/dev/null 2>&1
    printf '%s' "$input" | _ax_review_extract_json
  )
  if [ -z "$out" ]; then
    echo "  [PASS] $desc"
    _PASS=$((_PASS + 1))
  else
    echo "  [FAIL] $desc (got: $out)"
    _FAIL=$((_FAIL + 1))
  fi
}

# _ax_review_help 출력에 모든 옵션 키워드 포함 검증
_check_help_keyword() {
  local desc="$1" keyword="$2"
  local out
  out=$(
    source "$_ROOT/bin/ax-driven.sh" >/dev/null 2>&1
    _ax_review_help 2>&1
  )
  if echo "$out" | grep -q -- "$keyword"; then
    echo "  [PASS] $desc"
    _PASS=$((_PASS + 1))
  else
    echo "  [FAIL] $desc (keyword '$keyword' 없음)"
    _FAIL=$((_FAIL + 1))
  fi
}

echo "## ai-review help 출력"
_check_help_keyword "--all 옵션 노출"    "--all"
_check_help_keyword "--branch 옵션 노출" "--branch"
_check_help_keyword "--json 옵션 노출"   "--json"
_check_help_keyword "--help 옵션 노출"   "--help"
_check_help_keyword "JSON 복구 정책 노출" "auto-recovered"
echo ""

echo "## JSON 추출 복구"
_check_extract "prefix 텍스트에서 JSON 추출" \
  $'Here is the analysis:\n{"risk_level":"low","review_mode":"fast","has_must_fix":false,"confidence":"high"}' \
  '"risk_level":"low"'
_check_extract "펜스+후행 텍스트에서 JSON 추출" \
  $'```json\n{"a":1}\n```\nDone.' \
  '"a":1'
_check_extract_empty "잘린 JSON (} 누락) → 추출 실패" \
  '{"risk_level":"low",'
echo ""

# triage_once가 추출 복구 경로에 진입했을 때 stderr 로그 발생 확인
_check_recovery_log() {
  local desc="$1"
  local out
  out=$(
    source "$_ROOT/bin/ax-driven.sh" >/dev/null 2>&1
    _ax_review_triage() {
      printf 'prefix text\n{"risk_level":"low","review_mode":"fast","has_must_fix":false,"confidence":"high"}\n'
    }
    _ax_review_triage_once "$_ROOT" staged main 2>&1 >/dev/null
  )
  if echo "$out" | grep -q "triage JSON 추출로 복구"; then
    echo "  [PASS] $desc"
    _PASS=$((_PASS + 1))
  else
    echo "  [FAIL] $desc (got: $out)"
    _FAIL=$((_FAIL + 1))
  fi
}

echo "## 추출 복구 stderr 로그"
_check_recovery_log "추출 복구 시 stderr에 복구 로그 출력"
echo ""

# 결과
echo "---"
echo "결과: $_PASS passed, $_FAIL failed"
[ "$_FAIL" -eq 0 ] && exit 0 || exit 1

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
_check "providers/claude.sh"        "bash -n '$_ROOT/providers/claude.sh'"
_check "scripts/lib/utils.sh"       "bash -n '$_ROOT/scripts/lib/utils.sh'"
_check "scripts/commands/ai-commit.sh"  "bash -n '$_ROOT/scripts/commands/ai-commit.sh'"
_check "scripts/commands/ai-branch.sh"  "bash -n '$_ROOT/scripts/commands/ai-branch.sh'"
_check "scripts/commands/ai-review.sh"  "bash -n '$_ROOT/scripts/commands/ai-review.sh'"
_check "scripts/commands/ai-issue.sh"   "bash -n '$_ROOT/scripts/commands/ai-issue.sh'"
echo ""

# 2. 필수 디렉토리 존재
echo "## 필수 디렉토리"
_check "prompts/ 존재"    "[ -d '$_ROOT/prompts' ]"
_check "providers/ 존재"  "[ -d '$_ROOT/providers' ]"
_check "scripts/lib/ 존재"      "[ -d '$_ROOT/scripts/lib' ]"
_check "scripts/commands/ 존재" "[ -d '$_ROOT/scripts/commands' ]"
echo ""

# 3. source 가능 여부 (새 경로)
echo "## source 테스���"
_check "bin/ax-driven.sh source" "bash -c 'cd $_ROOT && source bin/ax-driven.sh && type ai-commit >/dev/null 2>&1'"
_check "scripts/claude/ax-driven.sh source (호환)" "bash -c 'cd $_ROOT && source scripts/claude/ax-driven.sh && type ai-commit >/dev/null 2>&1'"
echo ""

# 결과
echo "---"
echo "결과: $_PASS passed, $_FAIL failed"
[ "$_FAIL" -eq 0 ] && exit 0 || exit 1

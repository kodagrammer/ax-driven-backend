#!/bin/bash
# claude.sh — Claude Code provider
# claude --print 래퍼. 다른 provider 추가 시 이 파일과 동일한 인터페이스로 작성한다.

# claude --print 래퍼 — JSON 모드로 실행 후 토큰 사용량을 $_AX_TOKEN_FILE에 기록
# 사용법: _ax_claude <timeout_secs> [claude_args...]
# 권장 타임아웃: haiku=30, sonnet=90, opus=300
# jq 미설치 시 일반 --print로 fallback
_ax_claude() {
  _ac_secs="$1"; shift
  if ! command -v jq >/dev/null 2>&1; then
    _ax_timeout "$_ac_secs" claude --print "$@"
    return $?
  fi
  _ac_json=$(_ax_timeout "$_ac_secs" claude --print --output-format json "$@")
  _ac_rc=$?
  [ $_ac_rc -ne 0 ] && return $_ac_rc
  printf '%s\n' "$_ac_json" | jq -r '.result // ""'
  if [ -n "$_AX_TOKEN_FILE" ]; then
    _ac_model=""; _ac_prev=""
    for _ac_a in "$@"; do
      [ "$_ac_prev" = "--model" ] && _ac_model="$_ac_a"
      _ac_prev="$_ac_a"
    done
    printf '%s\n' "$_ac_json" | jq -r \
      --arg m "$_ac_model" \
      '"  토큰 (\($m)): input \(.usage.input_tokens) + cache_read \(.usage.cache_read_input_tokens // 0) + cache_create \(.usage.cache_creation_input_tokens // 0) / output \(.usage.output_tokens)  ($\(.total_cost_usd | tostring | .[0:6]))"' \
      > "$_AX_TOKEN_FILE" 2>/dev/null
  fi
  return 0
}

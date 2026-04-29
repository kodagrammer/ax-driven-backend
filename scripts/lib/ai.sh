#!/bin/bash
# ai.sh — provider-agnostic AI 호출 인터페이스
# bin/ax-driven.sh에서 source됨. 직접 실행하지 않는다.
#
# 사용법: _ax_ai <tier> [timeout_override]
#   tier: low | standard | high
#   stdin으로 프롬프트를 받아 현재 provider의 _ax_provider_call로 전달한다.
#
# 의존: _ax_provider_call (providers/*.sh에서 정의)

# --- tier별 기본 timeout (초) ---
_AX_TIMEOUT_LOW=30
_AX_TIMEOUT_STANDARD=90
_AX_TIMEOUT_HIGH=300

_ax_ai() {
  _ai_tier="$1"; shift

  case "$_ai_tier" in
    low)      _ai_timeout="${1:-$_AX_TIMEOUT_LOW}" ;;
    standard) _ai_timeout="${1:-$_AX_TIMEOUT_STANDARD}" ;;
    high)     _ai_timeout="${1:-$_AX_TIMEOUT_HIGH}" ;;
    *)
      echo "[Error] 알 수 없는 AI tier: $_ai_tier (low|standard|high)" >&2
      return 1
      ;;
  esac
  [ -n "${1:-}" ] && shift

  _ax_provider_call "$_ai_timeout" "$_ai_tier" "$@"
  _ai_rc=$?

  if [ $_ai_rc -eq 124 ]; then
    echo "[ERROR] AI 요청 timeout (${_ai_timeout}s 초과, tier: $_ai_tier). diff가 너무 크거나 네트워크가 느립니다." >&2
  fi

  return $_ai_rc
}

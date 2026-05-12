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

# --- subagent dispatch ---
# 사용법: _ax_dispatch <name> <tier>
#   name: subagent 이름 (security, test, architecture)
#   tier: low | standard | high
#   stdin으로 diff를 받아 name→file 변환 후 provider의 _ax_provider_dispatch로 전달한다.
#   timeout은 tier에 맞게 설정하여 provider에 전달.
#
# 의존: _ax_provider_dispatch (providers/*.sh에서 정의)
_ax_dispatch() {
  local _ad_name="$1" _ad_tier="$2"
  local _ad_file _ad_timeout

  if [ -z "$_ad_name" ] || [ -z "$_ad_tier" ]; then
    echo "[Error] 사용법: _ax_dispatch <name> <tier>" >&2
    return 1
  fi

  # provider dispatch 로드 확인
  if ! type _ax_provider_dispatch >/dev/null 2>&1; then
    echo "[Error] provider에 _ax_provider_dispatch가 정의되지 않았습니다." >&2
    return 1
  fi

  # name → agent 파일 매핑
  case "$_ad_name" in
    security)     _ad_file="${_AX_ROOT}/agents/security-reviewer.md" ;;
    test)         _ad_file="${_AX_ROOT}/agents/test-reviewer.md" ;;
    architecture) _ad_file="${_AX_ROOT}/agents/architecture-reviewer.md" ;;
    *)
      echo "[Error] unknown subagent: $_ad_name" >&2
      return 1
      ;;
  esac

  if [ ! -f "$_ad_file" ]; then
    echo "[Error] agent 파일 없음: $_ad_file" >&2
    return 1
  fi

  # tier에 맞는 timeout 설정
  case "$_ad_tier" in
    low)      _ad_timeout="$_AX_TIMEOUT_LOW" ;;
    standard) _ad_timeout="$_AX_TIMEOUT_STANDARD" ;;
    high)     _ad_timeout="$_AX_TIMEOUT_HIGH" ;;
    *)        _ad_timeout="$_AX_TIMEOUT_HIGH" ;;
  esac

  _AX_CURRENT_TIMEOUT="$_ad_timeout" _ax_provider_dispatch "$_ad_file" "$_ad_tier"
}

_ax_ai() {
  local _ai_tier="$1"; shift
  local _ai_timeout
  local _ai_rc

  case "$_ai_tier" in
    low)      _ai_timeout="$_AX_TIMEOUT_LOW" ;;
    standard) _ai_timeout="$_AX_TIMEOUT_STANDARD" ;;
    high)     _ai_timeout="$_AX_TIMEOUT_HIGH" ;;
    *)
      echo "[Error] 알 수 없는 AI tier: $_ai_tier (low|standard|high)" >&2
      return 1
      ;;
  esac

  # timeout override (숫자만 허용)
  if [ -n "${1:-}" ]; then
    case "$1" in
      *[!0-9]*) echo "[Error] timeout override는 숫자여야 합니다: $1" >&2; return 1 ;;
      *)        _ai_timeout="$1"; shift ;;
    esac
  fi

  # provider 로드 확인
  if ! type _ax_provider_call >/dev/null 2>&1; then
    echo "[Error] provider가 로드되지 않았습니다. bin/ax-driven.sh를 source했는지 확인하세요." >&2
    return 1
  fi

  _AX_CURRENT_TIMEOUT="$_ai_timeout" _ax_provider_call "$_ai_tier" "$@"
  _ai_rc=$?

  if [ $_ai_rc -eq 124 ]; then
    echo "[ERROR] AI 요청 timeout (${_ai_timeout}s 초과, tier: $_ai_tier). diff가 너무 크거나 네트워크가 느립니다." >&2
  fi

  return $_ai_rc
}

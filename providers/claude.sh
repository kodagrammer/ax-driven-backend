#!/bin/bash
# claude.sh — Claude Code provider
# claude --print 래퍼. 다른 provider 추가 시 이 파일과 동일한 인터페이스로 작성한다.
#
# 인터페이스 계약:
#   함수명: _ax_claude (provider별로 _ax_<name>)
#   입력:   stdin=프롬프트, $1=타임아웃(초), $2~=provider CLI 인자
#   출력:   stdout=AI 응답 본문, stderr=에러 메시지
#   종료코드: 0=성공, 비정상=실패
#   부가:   $_AX_TOKEN_FILE 설정 시 토큰 사용량 기록

# tier → Claude 모델 매핑
_ax_provider_call() {
  _pc_timeout="$1"; shift
  _pc_tier="$1"; shift

  case "$_pc_tier" in
    low)      _pc_model="haiku" ;;
    standard) _pc_model="sonnet" ;;
    high)     _pc_model="opus" ;;
    *)
      echo "[Error] 알 수 없는 tier: $_pc_tier" >&2
      return 1
      ;;
  esac

  _ax_claude "$_pc_timeout" --model "$_pc_model" "$@"
}

_ax_claude() {
  _ac_secs="$1"; shift

  # jq 미설치 시 일반 --print로 fallback (에러는 stderr로 자연 전달)
  if ! command -v jq >/dev/null 2>&1; then
    _ax_timeout "$_ac_secs" claude --print "$@"
    return $?
  fi

  _ac_json=$(_ax_timeout "$_ac_secs" claude --print --output-format json "$@")
  _ac_rc=$?

  # 비정상 종료 — 캡처된 응답에서 에러 추출 후 stderr로 전달
  if [ $_ac_rc -ne 0 ]; then
    if [ -n "$_ac_json" ]; then
      _ac_err=$(printf '%s\n' "$_ac_json" | jq -r '.error.message // .error // empty' 2>/dev/null)
      if [ -n "$_ac_err" ]; then
        echo "$_ac_err" >&2
      else
        printf '%s\n' "$_ac_json" >&2
      fi
    fi
    return $_ac_rc
  fi

  # 정상 종료지만 result가 비어있는 경우 — 에러 JSON일 수 있음
  _ac_result=$(printf '%s\n' "$_ac_json" | jq -r '.result // ""')
  if [ -z "$_ac_result" ]; then
    _ac_err=$(printf '%s\n' "$_ac_json" | jq -r '.error.message // .error // empty' 2>/dev/null)
    if [ -n "$_ac_err" ]; then
      echo "$_ac_err" >&2
      return 1
    fi
  fi

  printf '%s\n' "$_ac_result"

  # 토큰 사용량 기록
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

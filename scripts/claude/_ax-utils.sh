#!/bin/bash
# _ax-utils.sh — 공용 내부 함수
# ax-driven.sh에서 source됨. 직접 실행하지 않는다.

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

# timeout 호환 래퍼 (macOS는 coreutils의 gtimeout 사용, 없으면 timeout 없이 실행)
_ax_timeout() {
  _secs="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$_secs" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$_secs" "$@"
  else
    echo "[WARN] timeout 미설치 — 응답 지연 시 Ctrl+C로 중단하세요. (macOS: brew install coreutils)" >&2
    "$@"
  fi
}

# 임시 디렉토리 경로를 반환 (ax-driven/tmp)
_ax_tmp() {
  _root=$(_ax_find) || return 1
  echo "${_root}/tmp"
}

# 마지막 줄이 quit인지 확인
_ax_is_quit() {
  _last=$(tail -n 1 "$1" 2>/dev/null | tr -d '[:space:]')
  [ "$_last" = "quit" ]
}

# 임시 파일 안전장치 + 파이프라인 실행
# 사용법: _ax_run <tmp_dir> <name> <command>
_ax_run() {
  _tmp="$1"
  _name="$2"
  shift 2
  _cmd="$*"
  _file="$_tmp/${_name}.md"

  # 임시 파일 이미 존재 시 중단
  if [ -f "$_file" ]; then
    echo "" >&2
    echo "[WARN] 작업중이던 항목이 있습니다: $_file" >&2
    echo "  확인: \${EDITOR:-vi} $_file" >&2
    echo "  정리: _ax_done $_name" >&2
    echo "" >&2
    return 1
  fi

  mkdir -p "$_tmp"

  echo "[ax-driven] AI 생성 중..."
  _AX_TOKEN_FILE="$_tmp/token.log"
  export _AX_TOKEN_FILE
  eval "$_cmd" > "$_file" 2>"$_tmp/error.log"
  _run_rc=$?
  unset _AX_TOKEN_FILE

  if [ $_run_rc -ne 0 ] || [ ! -s "$_file" ]; then
    echo "[ERROR] AI 응답이 비어있습니다." >&2
    if [ -s "$_tmp/error.log" ]; then
      echo "  에러 로그: $_tmp/error.log" >&2
      cat "$_tmp/error.log" >&2
    fi
    rm -f "$_file" "$_tmp/token.log"
    return 1
  fi
  rm -f "$_tmp/error.log"

  echo "[ax-driven] 생성 완료: $_file"
  if [ -s "$_tmp/token.log" ]; then
    cat "$_tmp/token.log"
    rm -f "$_tmp/token.log"
  fi
  echo ""
  return 0
}

# 임시 파일 정리
# 사용법: _ax_done <name>  또는  _ax_done (전체 정리)
_ax_done() {
  _tmp=$(_ax_tmp) || return 1
  if [ -n "$1" ]; then
    _file="$_tmp/${1}.md"
    if [ -f "$_file" ]; then
      rm "$_file"
      echo "[ax-driven] 정리 완료: $_file"
    else
      echo "[ax-driven] 파일이 없습니다: $_file"
    fi
  else
    if [ -d "$_tmp" ] && [ "$(ls -A "$_tmp" 2>/dev/null)" ]; then
      rm -f "$_tmp"/*.md
      echo "[ax-driven] 전체 정리 완료: $_tmp"
    else
      echo "[ax-driven] 정리할 파일이 없습니다."
    fi
  fi
}

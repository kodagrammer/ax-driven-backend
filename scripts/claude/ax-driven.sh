#!/bin/bash
# ax-driven.sh — 호환성 래퍼
# 새 경로: bin/ax-driven.sh
# 이 파일은 기존 source 경로를 유지하기 위한 래퍼입니다.
#
# 기존: source ax-driven/scripts/claude/ax-driven.sh
# 신규: source ax-driven/bin/ax-driven.sh (권장)

# _ax_find가 아직 정의되지 않은 경우 임시로 정의하여 bin/ax-driven.sh를 찾는다
_ax_find() {
  _dir="$(pwd)"
  while [ "$_dir" != "/" ]; do
    _match=$(find "$_dir" -maxdepth 1 -type d -name 'ax-driven*' 2>/dev/null | head -n 10)
    for _candidate in $_match; do
      if [ -d "$_candidate/prompts" ]; then
        echo "$_candidate"
        return 0
      fi
    done
    case "$(basename "$_dir")" in
      ax-driven*)
        if [ -d "$_dir/prompts" ]; then
          echo "$_dir"
          return 0
        fi
        ;;
    esac
    _dir="$(dirname "$_dir")"
  done
  echo "[ERROR] ax-driven 디렉토리를 찾을 수 없습니다." >&2
  return 1
}

. "$(_ax_find)/bin/ax-driven.sh"

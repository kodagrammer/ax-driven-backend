#!/bin/bash
# ax-driven.sh — 호환성 래퍼
# 새 경로: bin/ax-driven.sh
# 이 파일은 기존 source 경로를 유지하기 위한 래퍼입니다.
#
# 기존: source ax-driven/scripts/claude/ax-driven.sh
# 신규: source ax-driven/bin/ax-driven.sh (권장)

_ax_wrapper_dir="$(cd "$(dirname "${BASH_SOURCE:-$0}")" && pwd)"
. "${_ax_wrapper_dir}/../../bin/ax-driven.sh"

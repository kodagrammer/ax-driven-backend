#!/bin/bash
# _ax-utils.sh — 호환성 래퍼
# 새 경로: scripts/lib/utils.sh + providers/claude.sh

_ax_wrapper_dir="$(cd "$(dirname "${BASH_SOURCE:-$0}")" && pwd)"
. "${_ax_wrapper_dir}/../lib/utils.sh"
. "${_ax_wrapper_dir}/../../providers/claude.sh"

#!/bin/bash
# _ax-utils.sh — 호환성 래퍼
# 새 경로: scripts/lib/utils.sh + providers/claude.sh
_ax_compat_root=$(_ax_find)
. "${_ax_compat_root}/scripts/lib/utils.sh"
. "${_ax_compat_root}/providers/claude.sh"

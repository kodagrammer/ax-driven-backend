#!/bin/bash
# _ai-issue.sh — 호환성 래퍼
# 새 경로: scripts/commands/ai-issue.sh

_ax_wrapper_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${_ax_wrapper_dir}/../commands/ai-issue.sh"

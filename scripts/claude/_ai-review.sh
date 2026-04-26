#!/bin/bash
# _ai-review.sh — 호환성 래퍼
# 새 경로: scripts/commands/ai-review.sh

_ax_wrapper_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${_ax_wrapper_dir}/../commands/ai-review.sh"

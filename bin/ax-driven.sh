#!/bin/bash
# bin/ax-driven.sh — AI 파이프라인 단축 명령어 (정식 진입점)
#
# 설치:
#   source /path/to/ax-driven/bin/ax-driven.sh
#
# 호환:
#   source /path/to/ax-driven/scripts/claude/ax-driven.sh  (기존 경로도 동작)
#
# 명령어:
#   ai-commit     커밋 메시지 생성 → 편집기 → 확인 후 커밋
#   ai-branch     이슈 기반 브랜치 생성 → 확인 → 체크아웃
#   ai-review     PR 아키텍처 리뷰 생성 → 편집기
#   ai-issue      작업 명세서 → 이슈 명령어 생성 → 편집기
#   _ax_done      임시 파일 정리

# --- 부트스트랩: BASH_SOURCE 기준으로 utils.sh를 먼저 로드하여 _ax_find를 확보 ---
_ax_bin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${_ax_bin_dir}/../scripts/lib/utils.sh"

# --- 모듈 로드 ---
_ax_root=$(_ax_find) || return 1

. "${_ax_root}/providers/claude.sh"
. "${_ax_root}/scripts/commands/ai-commit.sh"
. "${_ax_root}/scripts/commands/ai-branch.sh"
. "${_ax_root}/scripts/commands/ai-review.sh"
. "${_ax_root}/scripts/commands/ai-issue.sh"

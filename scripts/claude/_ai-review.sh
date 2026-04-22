#!/bin/sh
# _ai-review.sh — PR 아키텍처 리뷰
# ax-driven.sh에서 source됨. 직접 실행하지 않는다.

ai-review() {
  _ax_root=$(_ax_find) || return 1
  _tmp="${_ax_root}/tmp"
  _base="${1:-main}"

  # diff 확인
  if [ -z "$(git diff "${_base}...HEAD" --name-only)" ]; then
    echo "[ERROR] ${_base} 브랜치 대비 변경 사항이 없습니다." >&2
    return 1
  fi

  echo ""
  echo "  편집기에서 리뷰 결과를 확인해주세요."
  echo "  리뷰 반영 후 _ax_done review 로 정리해주세요."
  echo ""

  _ax_run "$_tmp" "review" "git diff '${_base}...HEAD' | cat '${_ax_root}/prompts/03-pr-reviewer.md' - | _ax_claude --model opus" || return 1

  ${EDITOR:-vi} "$_tmp/review.md"
}

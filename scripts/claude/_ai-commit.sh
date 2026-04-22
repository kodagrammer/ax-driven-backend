#!/bin/sh
# _ai-commit.sh — 커밋 메시지 생성
# ax-driven.sh에서 source됨. 직접 실행하지 않는다.

ai-commit() {
  _ax_root=$(_ax_find) || return 1
  _tmp="${_ax_root}/tmp"

  # 스테이징된 파일 확인
  if [ -z "$(git diff --cached --name-only)" ]; then
    echo "[ERROR] 스테이징된 변경 사항이 없습니다." >&2
    echo "  git add <파일> 후 다시 실행해주세요." >&2
    return 1
  fi

  # 사람 확인 구간 안내 (AI 생성 대기 중 읽을 수 있도록 먼저 출력)
  echo ""
  echo "  [주의] AI가 질문을 던졌다면, 커밋 취소(quit 기입) 후 수정한 소스코드를 확인 및 수정 후 다시 진행해주세요."
  echo "         --print 모드에서는 대화가 불가능합니다."
  echo ""
  echo "  편집기에서 커밋 메시지를 확인/수정해주세요."
  echo "  저장 후 종료하면 커밋이 진행됩니다."
  echo "  취소하려면 마지막 줄에 quit 을 작성해주세요."
  echo ""

  _ax_run "$_tmp" "commit" "git diff --cached | cat '${_ax_root}/prompts/00-git-commit-guide.md' - | _ax_claude 90 --model sonnet" || return 1

  ${EDITOR:-vi} "$_tmp/commit.md"

  # quit 감지 — 임시 파일 유지
  if _ax_is_quit "$_tmp/commit.md"; then
    echo "[ax-driven] 커밋이 취소되었습니다. 임시 파일 유지: $_tmp/commit.md"
    echo "  다시 수정: \${EDITOR:-vi} $_tmp/commit.md"
    echo "  정리: _ax_done commit"
    return 0
  fi

  # 커밋 시도 — 실패 시 임시 파일 유지
  if git commit -F "$_tmp/commit.md"; then
    _ax_done commit
  else
    echo ""
    echo "[ax-driven] 커밋이 실패했습니다. 임시 파일 유지: $_tmp/commit.md"
    echo "  메시지 수정: \${EDITOR:-vi} $_tmp/commit.md"
    echo "  수정 후 재시도: git commit -F $_tmp/commit.md"
    echo "  정리: _ax_done commit"
  fi
}

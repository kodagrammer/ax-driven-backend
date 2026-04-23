#!/bin/bash
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

  _commit_file="$_tmp/commit.md"

  # 임시 파일 안전장치
  if [ -f "$_commit_file" ]; then
    echo "" >&2
    echo "[WARN] 작업중이던 항목이 있습니다: $_commit_file" >&2
    echo "  확인: \${EDITOR:-vi} $_commit_file" >&2
    echo "  정리: _ax_done commit" >&2
    echo "" >&2
    return 1
  fi

  mkdir -p "$_tmp"

  echo "[ax-driven] AI 생성 중..."
  _AX_TOKEN_FILE="$_tmp/token.log"
  export _AX_TOKEN_FILE
  _sys_prompt=$(cat "${_ax_root}/prompts/00-git-commit-guide.md")
  git diff --cached \
    | _ax_claude 90 --model sonnet --system-prompt "$_sys_prompt" > "$_commit_file" 2>"$_tmp/error.log"
  _commit_rc=$?
  unset _AX_TOKEN_FILE

  if [ $_commit_rc -eq 124 ]; then
    echo "[Error-504] AI 응답 타임아웃 (90초 초과). 네트워크 상태를 확인하거나 다시 시도해주세요." >&2
    rm -f "$_commit_file" "$_tmp/token.log" "$_tmp/error.log"
    return 1
  fi
  if [ $_commit_rc -ne 0 ] || [ ! -s "$_commit_file" ]; then
    echo "[ERROR] AI 응답이 비어있습니다." >&2
    if [ -s "$_tmp/error.log" ]; then
      cat "$_tmp/error.log" >&2
    fi
    rm -f "$_commit_file" "$_tmp/token.log"
    return 1
  fi
  rm -f "$_tmp/error.log"

  echo "[ax-driven] 생성 완료: $_commit_file"
  if [ -s "$_tmp/token.log" ]; then
    cat "$_tmp/token.log"
    rm -f "$_tmp/token.log"
  fi
  echo ""

  ${EDITOR:-vi} "$_commit_file"

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

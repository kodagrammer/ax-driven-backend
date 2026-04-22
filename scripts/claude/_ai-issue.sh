#!/bin/sh
# _ai-issue.sh — 작업 명세서 → 이슈 생성
# ax-driven.sh에서 source됨. 직접 실행하지 않는다.

ai-issue() {
  _ax_root=$(_ax_find) || return 1
  _tmp="${_ax_root}/tmp"
  _spec="$_tmp/spec.md"
  _issue="$_tmp/issue.md"

  # issue 임시 파일 안전장치
  if [ -f "$_issue" ]; then
    echo "" >&2
    echo "[WARN] 작업중이던 항목이 있습니다: $_issue" >&2
    echo "  확인: \${EDITOR:-vi} $_issue" >&2
    echo "  정리: _ax_done issue" >&2
    echo "" >&2
    return 1
  fi

  mkdir -p "$_tmp"

  # Step 1: 명세서 작성
  if [ -f "$_spec" ]; then
    echo "[ax-driven] 기존 명세서를 사용합니다: $_spec"
  else
    cp "${_ax_root}/templates/03-work-specification.md" "$_spec"
    echo "[ax-driven] 명세서 템플릿을 복사했습니다: $_spec"
  fi

  echo ""
  echo "  편집기에서 작업 명세서를 작성해주세요."
  echo "  저장 후 종료하면 이슈 생성이 진행됩니다."
  echo "  취소하려면 마지막 줄에 quit 을 작성해주세요."
  echo ""

  ${EDITOR:-vi} "$_spec"

  # quit 감지 — 임시 파일 유지
  if _ax_is_quit "$_spec"; then
    echo "[ax-driven] 이슈 생성이 취소되었습니다. 임시 파일 유지: $_spec"
    echo "  다시 수정: \${EDITOR:-vi} $_spec"
    echo "  정리: _ax_done spec"
    return 0
  fi

  # Step 2: 이슈 명령어 생성
  echo "[ax-driven] AI 생성 중..."
  _AX_TOKEN_FILE="$_tmp/token.log"
  export _AX_TOKEN_FILE
  cat "${_ax_root}/prompts/04-issue-generator.md" "$_spec" | _ax_claude 30 --model haiku > "$_issue" 2>"$_tmp/error.log"
  _issue_rc=$?
  unset _AX_TOKEN_FILE

  if [ $_issue_rc -ne 0 ] || [ ! -s "$_issue" ]; then
    echo "[ERROR] AI 응답이 비어있습니다." >&2
    if [ -s "$_tmp/error.log" ]; then
      echo "  에러 로그: $_tmp/error.log" >&2
      cat "$_tmp/error.log" >&2
    fi
    rm -f "$_issue" "$_tmp/token.log"
    return 1
  fi
  rm -f "$_tmp/error.log"

  echo "[ax-driven] 생성 완료: $_issue"
  if [ -s "$_tmp/token.log" ]; then
    cat "$_tmp/token.log"
    rm -f "$_tmp/token.log"
  fi
  echo ""
  echo "  편집기에서 생성된 gh 명령어를 확인해주세요."
  echo "  확인 후 명령어를 복사하여 실행해주세요."
  echo "  완료 후 _ax_done issue && _ax_done spec 으로 정리해주세요."
  echo ""

  ${EDITOR:-vi} "$_issue"
}

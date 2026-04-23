#!/bin/bash
# _ai-review.sh — PR 아키텍처 리뷰
# ax-driven.sh에서 source됨. 직접 실행하지 않는다.

ai-review() {
  _ax_root=$(_ax_find) || return 1
  _tmp="${_ax_root}/tmp"
  _base="${1:-main}"
  _review_file="$_tmp/review.md"

  # _base 입력값 검증 (명령 주입 방지 — 브랜치명 허용 문자만 통과)
  case "$_base" in
    *[!a-zA-Z0-9/_.-]*)
      echo "[Error] 유효하지 않은 브랜치명입니다: $_base" >&2
      return 1 ;;
  esac

  # diff 확인
  if [ -z "$(git diff "${_base}...HEAD" --name-only)" ]; then
    echo "[ERROR] ${_base} 브랜치 대비 변경 사항이 없습니다." >&2
    return 1
  fi

  # 임시 파일 안전장치
  if [ -f "$_review_file" ]; then
    echo "" >&2
    echo "[WARN] 작업중이던 항목이 있습니다: $_review_file" >&2
    echo "  확인: \${EDITOR:-vi} $_review_file" >&2
    echo "  정리: _ax_done review" >&2
    echo "" >&2
    return 1
  fi

  mkdir -p "$_tmp"

  echo ""
  echo "  편집기에서 리뷰 결과를 확인해주세요."
  echo "  리뷰 반영 후 _ax_done review 로 정리해주세요."
  echo ""

  echo "[ax-driven] AI 생성 중..."
  _AX_TOKEN_FILE="$_tmp/token.log"
  export _AX_TOKEN_FILE
  { cat "${_ax_root}/prompts/03-pr-reviewer.md"; git diff "$_base...HEAD"; } \
    | _ax_claude 300 --model opus > "$_review_file" 2>"$_tmp/error.log"
  _rev_rc=$?
  unset _AX_TOKEN_FILE

  if [ $_rev_rc -ne 0 ] || [ ! -s "$_review_file" ]; then
    echo "[ERROR] AI 응답이 비어있습니다." >&2
    if [ -s "$_tmp/error.log" ]; then
      echo "  에러 로그: $_tmp/error.log" >&2
      cat "$_tmp/error.log" >&2
    fi
    rm -f "$_review_file" "$_tmp/token.log"
    return 1
  fi
  rm -f "$_tmp/error.log"

  echo "[ax-driven] 생성 완료: $_review_file"
  if [ -s "$_tmp/token.log" ]; then
    cat "$_tmp/token.log"
    rm -f "$_tmp/token.log"
  fi
  echo ""

  ${EDITOR:-vi} "$_review_file"
}

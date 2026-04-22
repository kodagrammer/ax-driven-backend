#!/bin/sh
# ax-driven.sh — AI 파이프라인 단축 명령어 (진입점)
#
# 설치:
#   ax-driven 디렉토리로 이동 후 source
#   cd /path/to/ax-driven && source ./scripts/claude/ax-driven.sh
#
# 명령어:
#   ai-commit     커밋 메시지 생성 → 편집기 → 확인 후 커밋
#   ai-branch     이슈 기반 브랜치 생성 → 확인 → 체크아웃
#   ai-review     PR 아키텍처 리뷰 생성 → 편집기
#   ai-issue      작업 명세서 → 이슈 명령어 생성 → 편집기
#   _ax_done      임시 파일 정리

# PWD에서 상위로 올라가며 ax-driven 디렉토리를 찾는다
# 탐지 기준: 디렉토리명이 "ax-driven"으로 시작하고 prompts/가 존재
_ax_find() {
  _dir="$(pwd)"
  while [ "$_dir" != "/" ]; do
    # 하위에 ax-driven* 디렉토리가 있는 경우 (subtree로 가져온 경우)
    _match=$(find "$_dir" -maxdepth 1 -type d -name 'ax-driven*' 2>/dev/null | head -n 10)
    for _candidate in $_match; do
      if [ -d "$_candidate/prompts" ]; then
        echo "$_candidate"
        return 0
      fi
    done
    # 현재 디렉토리 자체가 ax-driven* 레포인 경우
    case "$(basename "$_dir")" in
      ax-driven*)
        if [ -d "$_dir/prompts" ]; then
          echo "$_dir"
          return 0
        fi
        ;;
    esac
    _dir="$(dirname "$_dir")"
  done
  echo "[ERROR] ax-driven 디렉토리를 찾을 수 없습니다." >&2
  echo "  프로젝트 내에 ax-driven*/prompts/ 구조가 있는지 확인해주세요." >&2
  return 1
}

# --- 모듈 로드 ---
_ax_scripts="$(_ax_find)/scripts/claude"

. "${_ax_scripts}/_ax-utils.sh"
. "${_ax_scripts}/_ai-commit.sh"
. "${_ax_scripts}/_ai-branch.sh"
. "${_ax_scripts}/_ai-review.sh"
. "${_ax_scripts}/_ai-issue.sh"

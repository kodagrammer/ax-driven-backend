#!/bin/bash
# _ai-issue.sh — 작업 명세서 → GitHub 이슈 생성
# ax-driven.sh에서 source됨. 직접 실행하지 않는다.
#
# 사용법:
#   ai-issue                spec 파일이 없으면 템플릿 복사 → 편집기 → 이슈 생성
#   (tmp/spec*.md 배치)     복수 spec 파일 감지 → 각각 이슈 생성
#
# AI 호출 없음. spec에서 title/body를 추출하여 gh issue create로 직접 생성.
# 1 spec = 1 issue.
# type은 spec 내 HTML 주석 메타데이터(type: xxx)에서 추출. 미지정 시 enhancement.

# config/issue-labels.conf에서 label 조회
# 사용법: _issue_label <type>
# 출력: label 문자열. 설정 파일 없거나 매칭 없으면 빈 문자열.
_issue_label() {
  _il_conf="${_AX_ROOT}/config/issue-labels.conf"
  [ -f "$_il_conf" ] || return 0
  grep -v '^#' "$_il_conf" | grep "^${1}=" | head -1 | cut -d'=' -f2
}

# spec 파일에서 type 메타데이터 추출
# <!-- ... type: bug ... --> 형태에서 읽음
# 사용법: _issue_type <spec_file>
# 출력: "type label" (공백 구분, type은 사용자 원본 값)
_issue_type() {
  _it_raw=$(sed -n '/^<!--/,/-->/p' "$1" | grep -i '^type:' | head -1 | sed 's/^[Tt]ype: *//' | tr -d '[:space:]')
  _it_key=$(echo "$_it_raw" | tr '[:upper:]' '[:lower:]')
  [ -z "$_it_key" ] && _it_key="enhancement"

  # label: 설정 파일 우선, 없으면 내장 기본값
  _it_label=$(_issue_label "$_it_key")
  if [ -z "$_it_label" ]; then
    case "$_it_key" in
      bug)           _it_label="bug" ;;
      docs)          _it_label="documentation" ;;
      documentation) _it_label="documentation" ;;
      *)             _it_label="enhancement" ;;
    esac
  fi

  echo "$_it_key $_it_label"
}

# spec 파일에서 이슈 title 추출
# 사용법: _issue_title <spec_file> <type>
_issue_title() {
  _it_name=$(grep '^# ' "$1" | head -1 | sed 's/^# *//;s/^📄 Work Specification: *//')
  echo "${2}: ${_it_name}"
}

ai-issue() {
  _ax_root="$_AX_ROOT"
  _tmp="${_ax_root}/tmp"

  case "${1:-}" in
    --*)
      echo "[Error] 알 수 없는 옵션: $1" >&2
      return 1
      ;;
  esac

  # Ctrl+C 시그널 처리
  trap 'echo ""; echo "[ax-driven] 취소되었습니다."; trap - INT; return 1' INT

  # --- spec 파일 탐지 ---
  _spec_count=$(ls "$_tmp"/spec*.md 2>/dev/null | wc -l | tr -d ' ')

  # spec 파일이 없으면 → 안내
  if [ "$_spec_count" -eq 0 ]; then
    echo "[ax-driven] tmp/에 spec 파일이 없습니다."
    echo ""
    echo "  템플릿: ${_ax_root}/templates/03-work-specification.md"
    echo "  예시:   cp ${_ax_root}/templates/03-work-specification.md ${_tmp}/spec.md"
    echo ""
    echo "  명세서를 작성한 후 다시 ai-issue를 실행해주세요."
    echo "  복수 이슈는 tmp/에 spec01.md, spec02.md ... 형태로 배치하면 됩니다."
    trap - INT
    return 0
  else
    echo "[ax-driven] ${_spec_count}개 명세서를 발견했습니다:"
    for _f in "$_tmp"/spec*.md; do
      [ -f "$_f" ] || continue
      echo "  - $(basename "$_f")"
    done
    echo ""
  fi

  # --- 미리보기 ---
  echo "  생성할 이슈:"
  _idx=0
  for _spec in "$_tmp"/spec*.md; do
    [ -f "$_spec" ] || continue
    _idx=$((_idx + 1))
    _type_pair=$(_issue_type "$_spec")
    _type=$(echo "$_type_pair" | cut -d' ' -f1)
    _label=$(echo "$_type_pair" | cut -d' ' -f2)
    _t=$(_issue_title "$_spec" "$_type")
    echo "  [${_idx}] ${_t} [${_label}]"
  done

  echo ""
  printf "  진행하시겠습니까? (Y/n): "
  read -r _confirm

  case "$_confirm" in
    n|N)
      echo "[ax-driven] 취소되었습니다."
      trap - INT
      return 0
      ;;
  esac

  # --- 이슈 생성 ---
  echo ""
  for _spec in "$_tmp"/spec*.md; do
    [ -f "$_spec" ] || continue

    _type_pair=$(_issue_type "$_spec")
    _type=$(echo "$_type_pair" | cut -d' ' -f1)
    _label=$(echo "$_type_pair" | cut -d' ' -f2)
    _t=$(_issue_title "$_spec" "$_type")

    _result=$(gh issue create --title "$_t" --body-file "$_spec" --label "$_label" 2>"$_tmp/exec-error.log")
    _exec_rc=$?

    if [ "$_exec_rc" -eq 0 ] && [ -n "$_result" ]; then
      echo "  [OK] $_result"
    else
      echo "  [FAIL] $_t" >&2
      [ -s "$_tmp/exec-error.log" ] && sed 's/^/    /' "$_tmp/exec-error.log" >&2
    fi
    rm -f "$_tmp/exec-error.log"
  done

  # --- 정리 ---
  echo ""
  echo "[ax-driven] 완료. 정리: _ax_done"
  trap - INT
}

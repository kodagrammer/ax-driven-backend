#!/bin/bash
# _ai-branch.sh — 이슈 기반 브랜치 생성
# ax-driven.sh에서 source됨. 직접 실행하지 않는다.

_ax_branch_help() {
  echo "[Help] ai-branch — 컨벤션에 맞는 브랜치를 생성합니다." >&2
  echo "" >&2
  echo "  사용법: ai-branch -i <이슈링크|no-issue:설명> [--from <브랜치>]" >&2
  echo "" >&2
  echo "  옵션:" >&2
  echo "    -i      (필수) GitHub 이슈 URL 또는 no-issue:<작업내용>" >&2
  echo "    --from   (선택) 분기할 브랜치 (기본: main)" >&2
  echo "" >&2
  echo "  예시:" >&2
  echo "    ai-branch -i https://github.com/owner/repo/issues/3" >&2
  echo "    ai-branch -i no-issue:add-docs --from develop" >&2
}

# 브랜치명 검증 (컨벤션 정규식 + git ref 유효성)
_ax_validate_branch_name() {
  echo "$1" | grep -qE '^(feat|fix|docs|style|refactor|test|chore|hotfix|milestone)/(no-issue|[0-9]+)-[a-z0-9-]+$' \
    && git check-ref-format --branch "$1" >/dev/null 2>&1
}

ai-branch() {
  _ax_root="$_AX_ROOT"
  _tmp="${_ax_root}/tmp"
  _from="main"
  _issue=""

  # --- 인자 파싱 ---
  while [ $# -gt 0 ]; do
    case "$1" in
      --from)
        shift
        _from="$1"
        ;;
      -i)
        shift
        _issue="$1"
        ;;
      *)
        _ax_branch_help
        return 1
        ;;
    esac
    shift
  done

  # -i 필수 검증
  if [ -z "$_issue" ]; then
    _ax_branch_help
    return 1
  fi

  # 입력값 길이 제한 (URL은 200byte, 그 외 100byte)
  _byte_len=$(printf '%s' "$_issue" | wc -c | tr -d ' ')
  case "$_issue" in
    https://*)
      _byte_max=200 ;;
    *)
      _byte_max=100 ;;
  esac
  if [ "$_byte_len" -gt "$_byte_max" ]; then
    echo "[Error] -i 입력값이 ${_byte_max}byte를 초과합니다. (${_byte_len}byte)" >&2
    return 1
  fi

  # --- 사전처리 ---

  # origin 검증
  if ! git remote get-url origin >/dev/null 2>&1; then
    echo "[Error-404] origin 정보가 없습니다. 원격 브랜치를 연결해주세요." >&2
    echo "  git remote add origin <URL>" >&2
    return 1
  fi

  # 더티 워킹트리 검사
  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    echo "[Error] 커밋되지 않은 변경 사항이 있습니다." >&2
    echo "  git stash 또는 git commit 후 다시 실행해주세요." >&2
    return 1
  fi

  echo "[ax-driven] 원격 저장소 동기화 중..."
  if ! _ax_timeout 10 git remote update --prune >/dev/null 2>&1; then
    echo "[Error-504] 원격 저장소에 연결할 수 없습니다. 네트워크 상태를 확인해주세요." >&2
    return 1
  fi

  # from 브랜치 존재 확인 (로컬 또는 원격)
  if ! git rev-parse --verify "$_from" >/dev/null 2>&1 && \
     ! git rev-parse --verify "origin/$_from" >/dev/null 2>&1; then
    echo "[Error] '${_from}' 브랜치가 존재하지 않습니다." >&2
    return 1
  fi

  # --- 이슈 내용 수집 ---
  _issue_content=""
  case "$_issue" in
    no-issue:*)
      _desc="${_issue#no-issue:}"
      _issue_content="[no-issue] 작업 내용: ${_desc}"
      ;;
    https://github.com/*/issues/*)
      echo "[ax-driven] 이슈 조회 중..."
      _issue_err="$_tmp/gh_error.log"
      mkdir -p "$_tmp"
      _issue_content=$(_ax_timeout 30 gh issue view "$_issue" --json title,body,labels,number --jq '"[Issue #\(.number)] \(.title)\nLabels: \(.labels | map(.name) | join(", "))\n\(.body)"' 2>"$_issue_err")
      _rc=$?
      if [ $_rc -ne 0 ]; then
        echo "[Error] 이슈를 조회할 수 없습니다." >&2
        [ -s "$_issue_err" ] && cat "$_issue_err" >&2
        rm -f "$_issue_err"
        return 1
      fi
      rm -f "$_issue_err"
      ;;
    https://github.com/*)
      echo "[Error] GitHub URL이지만 이슈 형식이 아닙니다." >&2
      echo "  올바른 형식: https://github.com/owner/repo/issues/번호" >&2
      return 1
      ;;
    *)
      _issue_content="[no-issue] 작업 내용: ${_issue}"
      ;;
  esac

  # 기존 브랜치 목록 (최근 30개로 제한)
  _branches=$(git branch -a --sort=-committerdate --format='%(refname:short)' 2>/dev/null | head -n 30)

  # --- AI 브랜치명 생성 ---
  mkdir -p "$_tmp"
  _file="$_tmp/branch.md"

  echo "[ax-driven] 브랜치명 생성 중..."
  _AX_TOKEN_FILE="$_tmp/token.log"
  export _AX_TOKEN_FILE
  printf '%s\n\n---\n\n## 이슈 정보\n%s\n\n## 기존 브랜치 목록\n%s\n' \
    "$(cat "${_ax_root}/prompts/05-branch-name-guide.md")" \
    "$_issue_content" \
    "$_branches" \
    | _ax_claude 30 --model haiku > "$_file" 2>"$_tmp/error.log"
  _branch_rc=$?
  unset _AX_TOKEN_FILE

  if [ $_branch_rc -ne 0 ] || [ ! -s "$_file" ]; then
    if [ -s "$_tmp/error.log" ]; then
      echo "[ERROR] AI 요청 실패:" >&2
      cat "$_tmp/error.log" >&2
    else
      echo "[ERROR] AI 응답이 비어있습니다." >&2
    fi
    rm -f "$_file" "$_tmp/token.log"
    return 1
  fi
  rm -f "$_tmp/error.log"

  _branch_name=$(head -n 1 "$_file" | tr -d '[:space:]')
  rm -f "$_file"
  if [ -s "$_tmp/token.log" ]; then
    cat "$_tmp/token.log"
    rm -f "$_tmp/token.log"
  fi

  # 빈 브랜치명 방어
  if [ -z "$_branch_name" ]; then
    echo "[Error] AI가 브랜치명을 생성하지 못했습니다." >&2
    return 1
  fi

  # 브랜치명 포맷 검증
  if ! _ax_validate_branch_name "$_branch_name"; then
    echo ""
    echo "  [WARN] AI가 생성한 브랜치명이 컨벤션에 맞지 않습니다: $_branch_name"
    echo "  허용 포맷: <type>/<issue-ref>-<description>"
    echo "  예시: feat/3-add-login-api, fix/no-issue-typo"
    echo ""
    printf "  직접 입력하시겠습니까? (e[편집]/n[취소]): "
    read -r _fix_confirm
    case "$_fix_confirm" in
      e|E)
        printf "  브랜치명 입력: "
        read -r _branch_name
        if [ -z "$_branch_name" ]; then
          echo "[ax-driven] 취소되었습니다."
          return 0
        fi
        if ! _ax_validate_branch_name "$_branch_name"; then
          echo "[Error] 브랜치명이 컨벤션에 맞지 않거나 유효하지 않습니다: $_branch_name" >&2
          echo "  허용 포맷: <type>/<issue-ref>-<description>" >&2
          return 1
        fi
        ;;
      *)
        echo "[ax-driven] 취소되었습니다."
        return 0
        ;;
    esac
  fi

  echo ""
  echo "  생성할 브랜치: $_branch_name"
  echo "  분기 기준:     $_from"
  echo ""
  printf "  진행하시겠습니까? (Y/n/e[편집]): "
  read -r _confirm

  case "$_confirm" in
    n|N)
      echo "[ax-driven] 취소되었습니다."
      return 0
      ;;
    e|E)
      printf "  브랜치명 입력: "
      read -r _branch_name
      if [ -z "$_branch_name" ]; then
        echo "[ax-driven] 취소되었습니다."
        return 0
      fi
      if ! git check-ref-format --branch "$_branch_name" >/dev/null 2>&1; then
        echo "[Error] 유효하지 않은 브랜치명입니다: $_branch_name" >&2
        return 1
      fi
      ;;
  esac

  # --- 승인 후: from 브랜치 checkout & pull ---
  # detached HEAD 대응: symbolic-ref 실패 시 commit SHA로 복원
  _prev_branch=$(git symbolic-ref --short -q HEAD 2>/dev/null || git rev-parse HEAD 2>/dev/null)

  echo "[ax-driven] ${_from} 브랜치 최신화 중..."
  git checkout "$_from" >/dev/null 2>&1 || {
    echo "[Error] '${_from}' 브랜치로 전환할 수 없습니다." >&2
    return 1
  }
  _pull_out=$(_ax_timeout 30 git pull origin "$_from" 2>&1)
  _pull_rc=$?
  echo "$_pull_out" | tail -n 3
  if [ $_pull_rc -ne 0 ]; then
    echo "[Error] '${_from}' 병합 중 충돌이 발생했습니다." >&2
    git merge --abort >/dev/null 2>&1
    if [ -n "$_prev_branch" ]; then
      git checkout "$_prev_branch" >/dev/null 2>&1
      echo "  원래 브랜치(${_prev_branch})로 복원되었습니다." >&2
    fi
    echo "  충돌 해결 후 재시도해주세요." >&2
    return 1
  fi

  # 브랜치 생성 (로컬 + 원격)
  if ! git switch -c "$_branch_name" 2>&1; then
    echo "[Error] 브랜치 생성에 실패했습니다." >&2
    echo "  동일 이름의 브랜치가 이미 존재할 수 있습니다." >&2
    echo "  확인: git branch -a | grep $_branch_name" >&2
    # 원래 브랜치로 복원
    if [ -n "$_prev_branch" ]; then
      git checkout "$_prev_branch" >/dev/null 2>&1
    fi
    return 1
  fi

  echo "[ax-driven] 원격 브랜치 생성 중..."
  if _ax_timeout 30 git push -u origin "$_branch_name" 2>&1; then
    echo ""
    echo "[ax-driven] 브랜치 생성 완료: $_branch_name (local + origin)"
  else
    echo ""
    echo "[WARN] 로컬 브랜치는 생성되었으나, 원격 push에 실패했습니다." >&2
    printf "  로컬 브랜치를 삭제하시겠습니까? (y/N): " >&2
    read -r _del_confirm
    case "$_del_confirm" in
      y|Y)
        if [ -n "$_prev_branch" ]; then
          git checkout "$_prev_branch" >/dev/null 2>&1
        else
          git checkout "$_from" >/dev/null 2>&1
        fi
        git branch -d "$_branch_name" 2>&1
        echo "[ax-driven] 로컬 브랜치가 삭제되었습니다."
        ;;
      *)
        echo "  수동 push: git push -u origin $_branch_name" >&2
        echo "  현재 브랜치: $_branch_name" >&2
        if [ -n "$_prev_branch" ] && [ "$_prev_branch" != "$_branch_name" ]; then
          git checkout "$_prev_branch" >/dev/null 2>&1
          echo "  원래 브랜치(${_prev_branch})로 복원되었습니다." >&2
        fi
        ;;
    esac
  fi
}

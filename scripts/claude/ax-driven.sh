#!/bin/sh
# ax-driven.sh — AI 파이프라인 단축 명령어
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

# --- 내부 함수 ---

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

# 임시 디렉토리 경로를 반환 (ax-driven/tmp)
_ax_tmp() {
  _root=$(_ax_find) || return 1
  echo "${_root}/tmp"
}

# 마지막 줄이 quit인지 확인
_ax_is_quit() {
  _last=$(tail -n 1 "$1" 2>/dev/null | tr -d '[:space:]')
  [ "$_last" = "quit" ]
}

# 임시 파일 안전장치 + 파이프라인 실행
# 사용법: _ax_run <tmp_dir> <name> <command>
_ax_run() {
  _tmp="$1"
  _name="$2"
  shift 2
  _cmd="$*"
  _file="$_tmp/${_name}.md"

  # 임시 파일 이미 존재 시 중단
  if [ -f "$_file" ]; then
    echo "" >&2
    echo "[WARN] 작업중이던 항목이 있습니다: $_file" >&2
    echo "  확인: \${EDITOR:-vi} $_file" >&2
    echo "  정리: _ax_done $_name" >&2
    echo "" >&2
    return 1
  fi

  mkdir -p "$_tmp"

  echo "[ax-driven] AI 생성 중..."
  eval "$_cmd" > "$_file" 2>"$_tmp/error.log"

  if [ ! -s "$_file" ]; then
    echo "[ERROR] AI 응답이 비어있습니다." >&2
    if [ -s "$_tmp/error.log" ]; then
      echo "  에러 로그: $_tmp/error.log" >&2
      cat "$_tmp/error.log" >&2
    fi
    rm -f "$_file"
    return 1
  fi
  rm -f "$_tmp/error.log"

  echo "[ax-driven] 생성 완료: $_file"
  echo ""
  return 0
}

# 임시 파일 정리
# 사용법: _ax_done <name>  또는  _ax_done (전체 정리)
_ax_done() {
  _tmp=$(_ax_tmp) || return 1
  if [ -n "$1" ]; then
    _file="$_tmp/${1}.md"
    if [ -f "$_file" ]; then
      rm "$_file"
      echo "[ax-driven] 정리 완료: $_file"
    else
      echo "[ax-driven] 파일이 없습니다: $_file"
    fi
  else
    if [ -d "$_tmp" ] && [ "$(ls -A "$_tmp" 2>/dev/null)" ]; then
      rm -f "$_tmp"/*.md
      echo "[ax-driven] 전체 정리 완료: $_tmp"
    else
      echo "[ax-driven] 정리할 파일이 없습니다."
    fi
  fi
}

# --- 단축 명령어 ---

# 시나리오 1: 커밋 메시지 생성
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

  _ax_run "$_tmp" "commit" "git diff --cached | cat '${_ax_root}/prompts/00-git-commit-guide.md' - | claude --print --model sonnet" || return 1

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

# 시나리오 2: 브랜치 생성
ai-branch() {
  _ax_root=$(_ax_find) || return 1
  _tmp="${_ax_root}/tmp"
  _from="main"
  _issue=""

  # --- 인자 파싱 ---
  while [ $# -gt 0 ]; do
    case "$1" in
      -from)
        shift
        _from="$1"
        ;;
      -i)
        shift
        _issue="$1"
        ;;
      *)
        echo "[Help] ai-branch — 컨벤션에 맞는 브랜치를 생성합니다." >&2
        echo "" >&2
        echo "  사용법: ai-branch -i <이슈링크|no-issue:설명> [-from <브랜치>]" >&2
        echo "" >&2
        echo "  옵션:" >&2
        echo "    -i      (필수) GitHub 이슈 URL 또는 no-issue:<작업내용>" >&2
        echo "    -from   (선택) 분기할 브랜치 (기본: main)" >&2
        echo "" >&2
        echo "  예시:" >&2
        echo "    ai-branch -i https://github.com/owner/repo/issues/3" >&2
        echo "    ai-branch -i no-issue:add-docs -from develop" >&2
        return 1
        ;;
    esac
    shift
  done

  # -i 필수 검증
  if [ -z "$_issue" ]; then
    echo "[Help] ai-branch — 컨벤션에 맞는 브랜치를 생성합니다." >&2
    echo "" >&2
    echo "  사용법: ai-branch -i <이슈링크|no-issue:설명> [-from <브랜치>]" >&2
    echo "" >&2
    echo "  옵션:" >&2
    echo "    -i      (필수) GitHub 이슈 URL 또는 no-issue:<작업내용>" >&2
    echo "    -from   (선택) 분기할 브랜치 (기본: main)" >&2
    echo "" >&2
    echo "  예시:" >&2
    echo "    ai-branch -i https://github.com/owner/repo/issues/3" >&2
    echo "    ai-branch -i no-issue:add-docs -from develop" >&2
    return 1
  fi

  # 입력값 100byte 제한
  _byte_len=$(printf '%s' "$_issue" | wc -c | tr -d ' ')
  if [ "$_byte_len" -gt 100 ]; then
    echo "[Error] -i 입력값이 100byte를 초과합니다. (${_byte_len}byte)" >&2
    return 1
  fi

  # --- 사전처리: origin 검증 ---
  if ! git remote get-url origin >/dev/null 2>&1; then
    echo "[Error-404] origin 정보가 없습니다. 원격 브랜치를 연결해주세요." >&2
    echo "  git remote add origin <URL>" >&2
    return 1
  fi

  echo "[ax-driven] 원격 저장소 동기화 중..."
  if ! timeout 10 git remote update --prune >/dev/null 2>&1; then
    echo "[Error-504] 원격 저장소에 연결할 수 없습니다. 네트워크 상태를 확인해주세요." >&2
    return 1
  fi

  # from 브랜치 존재 확인 (로컬 또는 원격)
  if ! git rev-parse --verify "$_from" >/dev/null 2>&1 && \
     ! git rev-parse --verify "origin/$_from" >/dev/null 2>&1; then
    echo "[Error] '${_from}' 브랜치가 존재하지 않습니다." >&2
    return 1
  fi

  # from 브랜치로 이동 & pull
  echo "[ax-driven] ${_from} 브랜치 최신화 중..."
  git checkout "$_from" >/dev/null 2>&1 || {
    echo "[Error] '${_from}' 브랜치로 전환할 수 없습니다." >&2
    return 1
  }
  if ! git pull origin "$_from" 2>&1 | tail -n 3; then
    echo "[Error] '${_from}' 병합 중 충돌이 발생했습니다. 충돌 해결 후 재시도해주세요." >&2
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
      # GitHub 이슈 URL에서 owner/repo#number 추출
      _issue_num=$(echo "$_issue" | grep -oE '[0-9]+$')
      _issue_repo=$(echo "$_issue" | sed -n 's|.*github\.com/\([^/]*/[^/]*\)/issues/.*|\1|p')
      echo "[ax-driven] 이슈 #${_issue_num} 조회 중..."
      _issue_content=$(gh issue view "$_issue_num" --repo "$_issue_repo" --json title,body,labels --jq '"[Issue #\(.number // empty)] \(.title)\nLabels: \(.labels | map(.name) | join(", "))\n\(.body)"' 2>&1)
      if [ $? -ne 0 ]; then
        echo "[Error] 이슈 링크가 유효하지 않습니다." >&2
        echo "  상세: $_issue_content" >&2
        return 1
      fi
      ;;
    *)
      # URL도 no-issue: 접두사도 아닌 경우 → 작업 내용으로 간주
      _issue_content="[no-issue] 작업 내용: ${_issue}"
      ;;
  esac

  # 기존 브랜치 목록
  _branches=$(git branch -a --format='%(refname:short)' 2>/dev/null)

  # --- AI 브랜치명 생성 ---
  mkdir -p "$_tmp"
  _file="$_tmp/branch.md"

  echo "[ax-driven] 브랜치명 생성 중..."
  printf '%s\n\n---\n\n## 이슈 정보\n%s\n\n## 기존 브랜치 목록\n%s\n' \
    "$(cat "${_ax_root}/prompts/05-branch-name-guide.md")" \
    "$_issue_content" \
    "$_branches" \
    | claude --print --model haiku > "$_file" 2>"$_tmp/error.log"

  if [ ! -s "$_file" ]; then
    echo "[Error] AI 응답이 비어있습니다." >&2
    if [ -s "$_tmp/error.log" ]; then
      cat "$_tmp/error.log" >&2
    fi
    rm -f "$_file"
    return 1
  fi
  rm -f "$_tmp/error.log"

  _branch_name=$(head -n 1 "$_file" | tr -d '[:space:]')
  rm -f "$_file"

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
      ;;
  esac

  # 브랜치 생성 (로컬 + 원격)
  if ! git switch -c "$_branch_name" 2>&1; then
    echo "[Error] 브랜치 생성에 실패했습니다." >&2
    return 1
  fi

  echo "[ax-driven] 원격 브랜치 생성 중..."
  if git push -u origin "$_branch_name" 2>&1; then
    echo ""
    echo "[ax-driven] 브랜치 생성 완료: $_branch_name (local + origin)"
  else
    echo ""
    echo "[WARN] 로컬 브랜치는 생성되었으나, 원격 push에 실패했습니다." >&2
    echo "  수동 push: git push -u origin $_branch_name" >&2
  fi
}

# 시나리오 3: PR 아키텍처 리뷰
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

  _ax_run "$_tmp" "review" "git diff '${_base}...HEAD' | cat '${_ax_root}/prompts/03-pr-reviewer.md' - | claude --print" || return 1

  ${EDITOR:-vi} "$_tmp/review.md"
}

# 시나리오 4: 작업 명세서 → 이슈 생성
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
  cat "${_ax_root}/prompts/04-issue-generator.md" "$_spec" | claude --print > "$_issue" 2>"$_tmp/error.log"

  if [ ! -s "$_issue" ]; then
    echo "[ERROR] AI 응답이 비어있습니다." >&2
    if [ -s "$_tmp/error.log" ]; then
      echo "  에러 로그: $_tmp/error.log" >&2
      cat "$_tmp/error.log" >&2
    fi
    rm -f "$_issue"
    return 1
  fi
  rm -f "$_tmp/error.log"

  echo "[ax-driven] 생성 완료: $_issue"
  echo ""
  echo "  편집기에서 생성된 gh 명령어를 확인해주세요."
  echo "  확인 후 명령어를 복사하여 실행해주세요."
  echo "  완료 후 _ax_done issue && _ax_done spec 으로 정리해주세요."
  echo ""

  ${EDITOR:-vi} "$_issue"
}

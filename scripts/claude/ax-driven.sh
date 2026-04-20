#!/bin/sh
# ax-driven.sh — AI 파이프라인 단축 명령어
#
# 설치:
#   ax-driven 디렉토리로 이동 후 source
#   cd /path/to/ax-driven && source ./scripts/claude/ax-driven.sh
#
# 명령어:
#   ai-commit     커밋 메시지 생성 → 편집기 → 확인 후 커밋
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

# 시나리오 2: PR 아키텍처 리뷰
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

# 시나리오 3: 작업 명세서 → 이슈 생성
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

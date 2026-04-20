#!/bin/sh
# Git Hooks 해제 스크립트
# install.sh 로 설치한 심볼릭 링크만 제거합니다.

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
GIT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
GIT_HOOKS_DIR="$GIT_ROOT/.git/hooks"

HOOKS="pre-commit commit-msg pre-push"

for HOOK in $HOOKS; do
  TARGET="$GIT_HOOKS_DIR/$HOOK"

  if [ -L "$TARGET" ]; then
    rm "$TARGET"
    echo "[OK] $HOOK 해제 완료"
  elif [ -e "$TARGET" ]; then
    echo "[SKIP] $HOOK — 심볼릭 링크가 아닙니다. 수동 확인이 필요합니다."
  else
    echo "[SKIP] $HOOK — 설치되어 있지 않습니다."
  fi
done

echo ""
echo "해제가 완료되었습니다."

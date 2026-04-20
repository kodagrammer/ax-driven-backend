#!/bin/sh
# Git Hooks 설치 스크립트
# hooks/git/ 의 훅 파일을 .git/hooks/ 에 심볼릭 링크로 연결합니다.

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
GIT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
GIT_HOOKS_DIR="$GIT_ROOT/.git/hooks"

if [ ! -d "$GIT_HOOKS_DIR" ]; then
  echo "[ERROR] .git/hooks 디렉토리를 찾을 수 없습니다."
  echo "  git 저장소 루트에서 실행해주세요."
  exit 1
fi

HOOKS="pre-commit commit-msg pre-push"

for HOOK in $HOOKS; do
  SOURCE="$SCRIPT_DIR/$HOOK"
  TARGET="$GIT_HOOKS_DIR/$HOOK"

  if [ ! -f "$SOURCE" ]; then
    echo "[SKIP] $HOOK — 소스 파일이 없습니다."
    continue
  fi

  if [ -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
    echo "[SKIP] $HOOK — .git/hooks/$HOOK 에 기존 파일이 있습니다. 수동 확인 후 삭제해주세요."
    continue
  fi

  ln -sf "$SOURCE" "$TARGET"
  chmod +x "$SOURCE"
  echo "[OK] $HOOK 설치 완료 → $TARGET"
done

echo ""
echo "설치가 완료되었습니다."

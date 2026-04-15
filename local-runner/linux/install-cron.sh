#!/usr/bin/env bash
# Install curation cron entries.
# 既存の crontab に "# BEGIN curation" 〜 "# END curation" ブロックで追記する。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_PHASE="$(cd "$SCRIPT_DIR/.." && pwd)/run-phase.sh"

if [ ! -x "$RUN_PHASE" ]; then
  echo "ERROR: run-phase.sh not found or not executable: $RUN_PHASE" >&2
  exit 1
fi

# claude CLI のパスを PATH ヒントとして取得
CLAUDE_BIN="$(command -v claude || true)"
if [ -n "$CLAUDE_BIN" ]; then
  CLAUDE_DIR="$(dirname "$CLAUDE_BIN")"
else
  CLAUDE_DIR="$HOME/.local/bin"
fi

# 新しいエントリを生成
NEW_ENTRIES=$(cat <<EOF
# BEGIN curation
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$CLAUDE_DIR:$HOME/.local/bin
30 3 * * * /bin/bash $RUN_PHASE 1
30 4 * * * /bin/bash $RUN_PHASE 2
30 5 * * * /bin/bash $RUN_PHASE 3
# END curation
EOF
)

# 既存 crontab から curation ブロックを削除しつつ、新規を追加
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

{
  # 既存 crontab（curation ブロック以外）
  crontab -l 2>/dev/null | sed '/# BEGIN curation/,/# END curation/d'
  # 新規ブロック
  echo "$NEW_ENTRIES"
} > "$TMPFILE"

crontab "$TMPFILE"

echo "cron entries installed. Check with: crontab -l | grep curation"

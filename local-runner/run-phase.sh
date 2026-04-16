#!/usr/bin/env bash
# Curation Pipeline - Phase runner (Ubuntu / WSL 共通)
#
# Usage: run-phase.sh {1|2|3}
#
# 環境変数ファイル ~/.config/curation/runner.env を読み込む。
# 該当 Phase の prompt ファイルを読み、claude -p で起動する。
# ログは $CURATION_LOG_DIR に phaseN-YYYY-MM-DD.log として追記。
# ロックファイルで二重起動を防止する。

set -euo pipefail

PHASE="${1:-}"
if [[ ! "$PHASE" =~ ^[1-3]$ ]]; then
  echo "Usage: $0 {1|2|3}" >&2
  exit 2
fi

# 環境変数ロード
ENV_FILE="${CURATION_ENV:-$HOME/.config/curation/runner.env}"
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

# デフォルト値
REPO="${CURATION_REPO:-$HOME/Sources/curation-reports}"
LOG_DIR="${CURATION_LOG_DIR:-$HOME/.local/share/curation/logs}"
CLAUDE_ARGS="${CURATION_CLAUDE_ARGS:---allowedTools Bash,Read,Write,Edit,Glob,Grep,WebSearch,WebFetch --max-turns 80}"
export TZ="${TZ:-Asia/Tokyo}"

# 前提チェック
for cmd in git claude gh python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $cmd" >&2
    exit 3
  fi
done

if [ ! -d "$REPO/.git" ]; then
  echo "ERROR: repository not found: $REPO" >&2
  exit 3
fi

if [ -z "$(git config user.name)" ] || [ -z "$(git config user.email)" ]; then
  echo "ERROR: git user.name / user.email が未設定です。リポジトリで以下を実行してください:" >&2
  echo "  cd $REPO" >&2
  echo "  git config user.name \"YOUR_NAME\"" >&2
  echo "  git config user.email \"YOUR_EMAIL\"" >&2
  exit 3
fi

# ログ準備
mkdir -p "$LOG_DIR"
DATE=$(date +%Y-%m-%d)
LOG_FILE="$LOG_DIR/phase${PHASE}-${DATE}.log"

# ロック
LOCK_FILE="/tmp/curation-phase${PHASE}.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "$(date -Iseconds) phase${PHASE}: already running, skipping" | tee -a "$LOG_FILE"
  exit 0
fi

{
  echo ""
  echo "===== Phase ${PHASE} start: $(date -Iseconds) ====="
  cd "$REPO"

  # 最新を取得
  git fetch origin main
  git checkout main
  git pull --ff-only origin main

  # Phase 実行
  PROMPT="config/prompts/phase${PHASE}.md を読み、その手順に従って Phase ${PHASE} を実行してください。"
  # shellcheck disable=SC2086
  claude -p "$PROMPT" $CLAUDE_ARGS
  EXIT=$?

  echo "===== Phase ${PHASE} end: $(date -Iseconds), exit=${EXIT} ====="
  exit "$EXIT"
} 2>&1 | tee -a "$LOG_FILE"

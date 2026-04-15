#!/usr/bin/env bash
# Install curation systemd user units.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEMD_DIR="$SCRIPT_DIR/systemd"
TARGET_DIR="$HOME/.config/systemd/user"
RUN_PHASE="$(cd "$SCRIPT_DIR/.." && pwd)/run-phase.sh"

if [ ! -x "$RUN_PHASE" ]; then
  echo "ERROR: run-phase.sh not found or not executable: $RUN_PHASE" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"

# Service/Timer 各ファイルをコピーし、ExecStart のパスをリポジトリの実パスに書き換える
for N in 1 2 3; do
  SERVICE_SRC="$SYSTEMD_DIR/curation-phase${N}.service"
  TIMER_SRC="$SYSTEMD_DIR/curation-phase${N}.timer"
  SERVICE_DST="$TARGET_DIR/curation-phase${N}.service"
  TIMER_DST="$TARGET_DIR/curation-phase${N}.timer"

  # ExecStart パスは絶対パスに展開
  sed "s|{{RUN_PHASE}}|$RUN_PHASE|g" "$SERVICE_SRC" > "$SERVICE_DST"
  cp "$TIMER_SRC" "$TIMER_DST"
done

systemctl --user daemon-reload

for N in 1 2 3; do
  systemctl --user enable --now "curation-phase${N}.timer"
done

echo "systemd user timers installed and started."
echo ""
echo "Status:"
systemctl --user list-timers | grep curation || true
echo ""
echo "Tip: sudo loginctl enable-linger \$USER でログアウト後も動作させる"

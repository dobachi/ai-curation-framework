#!/usr/bin/env bash
# Remove curation cron entries and/or systemd user units.

set -euo pipefail

TARGET_DIR="$HOME/.config/systemd/user"

# systemd user units を停止・削除
if command -v systemctl >/dev/null 2>&1; then
  for N in 1 2 3; do
    TIMER="curation-phase${N}.timer"
    SERVICE="curation-phase${N}.service"
    if systemctl --user list-unit-files --no-legend 2>/dev/null | grep -q "^${TIMER}"; then
      systemctl --user disable --now "$TIMER" || true
    fi
    rm -f "$TARGET_DIR/$TIMER" "$TARGET_DIR/$SERVICE"
  done
  systemctl --user daemon-reload 2>/dev/null || true
  echo "systemd user units removed."
fi

# cron entries を削除
if crontab -l 2>/dev/null | grep -q "# BEGIN curation"; then
  TMPFILE=$(mktemp)
  trap 'rm -f "$TMPFILE"' EXIT
  crontab -l 2>/dev/null | sed '/# BEGIN curation/,/# END curation/d' > "$TMPFILE"
  crontab "$TMPFILE"
  echo "cron entries removed."
fi

echo "Uninstall complete."

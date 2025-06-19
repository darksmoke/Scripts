#!/bin/bash
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
source "$SCRIPT_DIR/send_telegram.sh"
source "$SCRIPT_DIR/config.ini"

if command -v mdadm &> /dev/null; then
  STATUS=$(cat /proc/mdstat | grep -E '\[.*U.*\]' || true)

  if echo "$STATUS" | grep -q '_'; then
    HOST=$(hostname)
    TIME=$(date '+%Y-%m-%d %H:%M:%S')
    MSG="⚠️ *$HOST*
    🕒 $TIME
    RAID в состоянии DEGRADED:
    \`\`\`$STATUS\`\`\`"
    send_telegram "$MSG"
  fi
fi

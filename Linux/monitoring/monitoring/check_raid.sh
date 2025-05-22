#!/bin/bash
CONFIG_FILE="config.ini"
source send_telegram.sh

if command -v mdadm &> /dev/null; then
  STATUS=$(cat /proc/mdstat | grep -E '\[.*U.*\]' || true)

  if echo "$STATUS" | grep -q '_'; then
    HOST=$(hostname)
    TIME=$(date '+%Y-%m-%d %H:%M:%S')
    MSG="⚠️ *$HOST*\n🕒 $TIME\nRAID в состоянии DEGRADED:\n\`\`\`\n$STATUS\n\`\`\`"
    send_telegram "$MSG"
  fi
fi

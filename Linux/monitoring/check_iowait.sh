#!/bin/bash
# v2

CONFIG_FILE="config.ini"
source "$(dirname "$0")/send_telegram.sh"

THRESHOLD=5.0  # Порог в %

IOWAIT=$(iostat -c 1 2 | awk '/^ / {io+=$4} END {print io}')
IOWAIT=${IOWAIT//,/.}  # заменяем запятую на точку

if (( $(echo "$IOWAIT > $THRESHOLD" | bc -l) )); then
  HOST=$(hostname)
  TIME=$(date '+%Y-%m-%d %H:%M:%S')

  MSG="⚠️ *${HOST}*
🕒 ${TIME}
Высокий IO wait: *${IOWAIT}%*"

  send_telegram "$MSG"
fi

#!/bin/bash
# v2
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
source "$SCRIPT_DIR/send_telegram.sh"
source "$SCRIPT_DIR/config.ini"

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

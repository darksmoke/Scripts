#!/bin/bash
CONFIG_FILE="config.ini"
source send_telegram.sh

THRESHOLD=10
IOWAIT=$(iostat -c 1 2 | awk '/^ / {print $4}' | tail -1 | cut -d. -f1)

if [[ $IOWAIT -gt $THRESHOLD ]]; then
  HOST=$(hostname)
  TIME=$(date '+%Y-%m-%d %H:%M:%S')
  MSG="⚠️ *$HOST*\n🕒 $TIME\nВысокий IO Wait: ${IOWAIT}%"
  send_telegram "$MSG"
fi

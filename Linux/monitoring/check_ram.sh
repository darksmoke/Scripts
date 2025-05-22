#!/bin/bash
CONFIG_FILE="config.ini"
source send_telegram.sh

THRESHOLD=5

FREE=$(free -m | awk '/Mem:/ {print $7}')
TOTAL=$(free -m | awk '/Mem:/ {print $2}')
PERCENT=$(( 100 * FREE / TOTAL ))


if [[ $PERCENT -lt $THRESHOLD ]]; then
  HOST=$(hostname)
  TIME=$(date '+%Y-%m-%d %H:%M:%S')
  MSG="⚠️ *$HOST*
🕒 $TIME
Свободной RAM: ${PERCENT}%"
  send_telegram "$MSG"
fi

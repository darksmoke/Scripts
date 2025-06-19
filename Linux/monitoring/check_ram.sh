#!/bin/bash
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
source "$SCRIPT_DIR/send_telegram.sh"
source "$SCRIPT_DIR/config.ini"

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
